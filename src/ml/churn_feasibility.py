"""Run the Phase 10, non-production model feasibility experiment.

Run from the repository root:
    .venv/Scripts/python.exe src/ml/churn_feasibility.py

The only database operation is the SELECT-only Phase 8/9 cutoff-safe dataset
query. The script writes a report, metrics CSV, and calibration figure.
"""
from pathlib import Path
import sys
import warnings

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import sklearn
from sklearn.calibration import calibration_curve
from sklearn.metrics import (
    average_precision_score, balanced_accuracy_score, brier_score_loss,
    confusion_matrix, f1_score, precision_score, recall_score, roc_auc_score,
)
from sklearn.model_selection import StratifiedKFold

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from src.database.connection import create_database_engine
from src.ml.feature_pipeline import FEATURES, SEED, build_pipeline, transformed_feature_names

DATA_SQL = ROOT / "sql/09_statistics/01_statistical_dataset.sql"
REPORT = ROOT / "reports/10_ml_feasibility.md"
METRICS_PATH = ROOT / "reports/10_ml_metrics.csv"
FIGURE_DIR = ROOT / "reports/figures"
EXPECTED = {"A_2012": (2799, 2342, 457), "B_2013": (6206, 1050, 5156)}
THRESHOLDS = (0.10, 0.20, 0.50)


def markdown_table(frame, digits=3):
    """Render Markdown tables without requiring pandas' optional tabulate."""
    columns=list(frame.columns)
    def cell(value):
        if pd.isna(value): return ""
        if isinstance(value, (float, np.floating)): return f"{value:.{digits}f}"
        return str(value).replace("|", "\\|").replace("\n", " ")
    lines=["| " + " | ".join(columns) + " |", "|" + "|".join(["---"]*len(columns)) + "|"]
    lines += ["| " + " | ".join(cell(v) for v in row) + " |" for row in frame.itertuples(index=False,name=None)]
    return "\n".join(lines)


def fmt(x, digits=3):
    return "NA" if x is None or pd.isna(x) else f"{x:.{digits}f}"


def rate(x):
    return "NA" if x is None or pd.isna(x) else f"{x:.1%}"


def metric_values(y_true, pred, prob=None):
    y_true = np.asarray(y_true, dtype=int)
    pred = np.asarray(pred, dtype=int)
    tn, fp, fn, tp = confusion_matrix(y_true, pred, labels=[0, 1]).ravel()
    return {
        "roc_auc": roc_auc_score(y_true, prob) if prob is not None else np.nan,
        "pr_auc_average_precision": average_precision_score(y_true, prob) if prob is not None else np.nan,
        "target_prevalence": float(np.mean(y_true)),
        "precision": precision_score(y_true, pred, zero_division=0),
        "recall": recall_score(y_true, pred, zero_division=0),
        "f1": f1_score(y_true, pred, zero_division=0),
        "balanced_accuracy": balanced_accuracy_score(y_true, pred),
        "brier_score": brier_score_loss(y_true, prob) if prob is not None else np.nan,
        "tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp),
    }


def cv_predictions(frame, model_kind, snapshot):
    """Generate one out-of-fold probability per unique customer in snapshot."""
    y = frame.AnalyticalChurn.to_numpy(dtype=int)
    ids = frame.CustomerID.to_numpy()
    x = frame[FEATURES]
    splitter = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
    probabilities = np.full(len(frame), np.nan)
    fold_number = np.full(len(frame), -1, dtype=int)
    for fold, (train_idx, test_idx) in enumerate(splitter.split(x, y), start=1):
        overlap = set(ids[train_idx]).intersection(ids[test_idx])
        if overlap:
            raise AssertionError(f"Customer overlap inside {snapshot} CV fold {fold}")
        pipeline = build_pipeline(model_kind, SEED + fold)
        pipeline.fit(x.iloc[train_idx], y[train_idx])
        probabilities[test_idx] = pipeline.predict_proba(x.iloc[test_idx])[:, 1]
        fold_number[test_idx] = fold
    if np.isnan(probabilities).any() or (fold_number < 1).any():
        raise AssertionError("Every customer must receive exactly one out-of-fold score")
    return probabilities, fold_number


def append_metric_rows(rows, experiment, model_name, y, prob=None, fixed_pred=None):
    for threshold in (THRESHOLDS if fixed_pred is None else (0.50,)):
        pred = fixed_pred if fixed_pred is not None else (prob >= threshold).astype(int)
        values = metric_values(y, pred, prob)
        rows.append({"experiment": experiment, "model": model_name,
                     "threshold": threshold, **values})


def model_diagnostics(frame, snapshot, model_kind):
    """Refit on all snapshot rows for descriptive coefficients/importances only."""
    pipeline = build_pipeline(model_kind, SEED)
    y = frame.AnalyticalChurn.to_numpy(dtype=int)
    pipeline.fit(frame[FEATURES], y)
    names = transformed_feature_names(pipeline)
    if model_kind == "logistic":
        values = pipeline.named_steps["model"].coef_[0]
        desc = "standardized logistic coefficient"
    else:
        values = pipeline.named_steps["model"].feature_importances_
        desc = "random forest impurity importance"
    out = pd.DataFrame({"feature": names, "value": values, "measure": desc})
    out["snapshot"] = snapshot
    return out.sort_values("value", key=(lambda s: s.abs()) if model_kind == "logistic" else None,
                           ascending=False).head(12)


def calibration_table(frame, probabilities, model_name, snapshot):
    y = frame.AnalyticalChurn.to_numpy(dtype=int)
    temp = pd.DataFrame({"y": y, "p": probabilities})
    temp["bin"] = pd.qcut(temp.p, q=10, duplicates="drop")
    grouped = temp.groupby("bin", observed=True).agg(N=("y", "size"),
        MeanPredicted=("p", "mean"), ObservedNonReturnRate=("y", "mean"))
    grouped = grouped.reset_index(drop=True)
    grouped.insert(0, "Snapshot", snapshot)
    grouped.insert(1, "Model", model_name)
    return grouped


def main():
    engine = create_database_engine()
    try:
        with engine.connect() as conn:
            df = pd.read_sql_query(DATA_SQL.read_text(encoding="utf-8-sig"), conn)
    finally:
        engine.dispose()

    df["AnalyticalChurn"] = pd.to_numeric(df.AnalyticalChurn).astype(int)
    if df.duplicated(["SnapshotID", "CustomerID"]).any():
        raise AssertionError("Duplicate customer within a snapshot")
    if set(df.SnapshotID) != set(EXPECTED):
        raise AssertionError("Unexpected snapshot identifiers")
    if (df.RecencyDays < 0).any() or (df.Frequency < 1).any():
        raise AssertionError("Invalid cutoff-derived recency or frequency")
    if not df.AverageDaysBetweenOrders.isna().equals(df.MedianDaysBetweenOrders.isna()):
        raise AssertionError("Mean/median gap null patterns differ unexpectedly")
    if df.loc[df.Frequency.eq(1), "AverageDaysBetweenOrders"].notna().any():
        raise AssertionError("One-order customers must have no observed gap")
    if df.loc[df.Frequency.gt(1), "AverageDaysBetweenOrders"].isna().any():
        raise AssertionError("Repeat customers should have historical purchase gaps")

    metric_rows = []
    per_snapshot = {}
    importances = []
    calibration = []
    report_population = []
    quality_rows = []
    for snapshot, (n_expected, churn_expected, return_expected) in EXPECTED.items():
        frame = df.loc[df.SnapshotID.eq(snapshot)].copy().reset_index(drop=True)
        y = frame.AnalyticalChurn.to_numpy(dtype=int)
        n, positives = len(frame), int(y.sum())
        if (n, positives, n - positives) != (n_expected, churn_expected, return_expected):
            raise AssertionError(f"{snapshot} population/labels failed expected reconciliation")
        prevalence = positives / n
        # The baseline label and probability are deliberately distinct: a
        # majority-class classifier predicts the common class; the probability
        # baseline predicts the observed prevalence for Brier scoring only.
        majority_label = int(prevalence >= .5)
        majority_prediction = np.full(n, majority_label, dtype=int)
        prevalence_probability = np.full(n, prevalence, dtype=float)
        append_metric_rows(metric_rows, snapshot, "Majority-class baseline", y,
                           prevalence_probability, majority_prediction)
        # One shared, untrained rule makes the regime reversal visible.
        simple_rule = frame.OneOrderSoFar.astype(int).to_numpy()
        append_metric_rows(metric_rows, snapshot, "Rule: one order so far => non-return", y,
                           simple_rule.astype(float), fixed_pred=simple_rule)

        data = {"y": y, "ids": frame.CustomerID.to_numpy(), "n": n,
                "prevalence": prevalence, "majority": majority_prediction,
                "probabilities": {}, "folds": {}}
        for kind, name in [("logistic", "Regularized Logistic Regression"),
                           ("random_forest", "Random Forest")]:
            prob, folds = cv_predictions(frame, kind, snapshot)
            append_metric_rows(metric_rows, snapshot, name, y, prob)
            data["probabilities"][name] = prob
            data["folds"][name] = folds
            calibration.append(calibration_table(frame, prob, name, snapshot))
            importances.append(model_diagnostics(frame, snapshot, kind))

        # Imbalance and leakage-safe feature diagnostics.
        gap_null = int(frame.AverageDaysBetweenOrders.isna().sum())
        assert gap_null == int(frame.Frequency.eq(1).sum())
        corr = frame[FEATURES].corr(numeric_only=True)
        high_corr = []
        for i, left in enumerate(corr.columns):
            for right in corr.columns[i + 1:]:
                value = corr.loc[left, right]
                if pd.notna(value) and abs(value) >= .90:
                    high_corr.append((left, right, float(value)))
        skewed = [c for c in ["RecencyDays", "Frequency", "DaysSinceFirstOrder",
                              "AverageDaysBetweenOrders", "OnlineOrderShare"]
                  if abs(frame[c].dropna().skew()) >= 1]
        quality_rows.append({"Snapshot": snapshot, "N": n, "Prevalence": prevalence,
                             "Missing gap": gap_null, "One-order": int(frame.Frequency.eq(1).sum()),
                             "Skewed": ", ".join(skewed) or "None",
                             "High correlation pairs": "; ".join(f"{a}/{b}={v:.2f}" for a,b,v in high_corr) or "None"})
        report_population.append((snapshot, frame, data, high_corr, skewed, gap_null))
        per_snapshot[snapshot] = data

    # Strictly labeled cross-regime stress experiment. The preprocessing is
    # trained on A only; IDs overlap by design and results are not prospective.
    a = df.loc[df.SnapshotID.eq("A_2012")].copy().reset_index(drop=True)
    b = df.loc[df.SnapshotID.eq("B_2013")].copy().reset_index(drop=True)
    a_ids, b_ids = set(a.CustomerID), set(b.CustomerID)
    overlap_ids = a_ids & b_ids
    b_new = b.CustomerID.isin(b_ids - a_ids).to_numpy()
    stress = {}
    for kind, name in [("logistic", "Regularized Logistic Regression"),
                       ("random_forest", "Random Forest")]:
        pipeline = build_pipeline(kind, SEED)
        pipeline.fit(a[FEATURES], a.AnalyticalChurn.astype(int))
        b_prob = pipeline.predict_proba(b[FEATURES])[:, 1]
        yb = b.AnalyticalChurn.to_numpy(dtype=int)
        for label, mask in [("A_to_B stress (all B; overlap allowed)", np.ones(len(b), dtype=bool)),
                            ("A_to_B stress (B IDs overlapping A)", b.CustomerID.isin(overlap_ids).to_numpy()),
                            ("A_to_B stress (B IDs not in A)", b_new)]:
            if mask.sum() == 0:
                continue
            append_metric_rows(metric_rows, label, name, yb[mask], b_prob[mask])
            stress[(name, label)] = (yb[mask], b_prob[mask])

    metrics = pd.DataFrame(metric_rows)
    metrics.to_csv(METRICS_PATH, index=False, float_format="%.6f")
    calibration_df = pd.concat(calibration, ignore_index=True)
    importance_df = pd.concat(importances, ignore_index=True)

    FIGURE_DIR.mkdir(parents=True, exist_ok=True)
    figure_path = FIGURE_DIR / "10_calibration.png"
    fig, axes = plt.subplots(1, 2, figsize=(10, 4), sharex=True, sharey=True)
    for ax, snapshot in zip(axes, ["A_2012", "B_2013"]):
        subset = calibration_df[calibration_df.Snapshot.eq(snapshot)]
        ax.plot([0, 1], [0, 1], linestyle="--", color="gray", label="Perfect calibration")
        for model_name, group in subset.groupby("Model"):
            ax.plot(group.MeanPredicted, group.ObservedNonReturnRate, marker="o", label=model_name)
        ax.set_title(snapshot); ax.set_xlabel("Mean predicted non-return probability")
        ax.set_ylabel("Observed 365-day non-return rate"); ax.legend(fontsize=7)
    fig.tight_layout(); fig.savefig(figure_path, dpi=150); plt.close(fig)

    # Tables for report, with model metrics at the prespecified 0.50 threshold.
    default_metrics = metrics[np.isclose(metrics.threshold, .5)].copy()
    metric_cols = ["experiment", "model", "target_prevalence", "roc_auc",
                   "pr_auc_average_precision", "precision", "recall", "f1",
                   "balanced_accuracy", "brier_score", "tn", "fp", "fn", "tp"]
    summary_table = markdown_table(default_metrics[metric_cols])
    threshold_rows = metrics[(metrics["model"].isin(["Regularized Logistic Regression", "Random Forest"])) &
                             (metrics.experiment.isin(EXPECTED))]
    threshold_table = markdown_table(threshold_rows[["experiment", "model", "threshold", "precision", "recall", "f1", "balanced_accuracy"]])
    quality_table = markdown_table(pd.DataFrame(quality_rows))
    calibration_table_text = markdown_table(calibration_df)
    imp_parts=[]
    for (snapshot, measure), part in importance_df.groupby(["snapshot", "measure"]):
        imp_parts.append(f"### {snapshot}: {measure}\n\n" + markdown_table(part[["feature", "value"]]))
    importance_text="\n\n".join(imp_parts)

    # Stress summary by identity overlap group, no attempt to label it a holdout.
    overlap_count=len(overlap_ids); overlap_rate=overlap_count/len(b_ids)
    stress_text=markdown_table(metrics[(metrics.experiment.str.startswith("A_to_B stress")) & np.isclose(metrics.threshold,.5)][metric_cols])
    corr_text=[]
    for snapshot, _, _, pairs, skewed, gap_null in report_population:
        corr_text.append(f"- **{snapshot}:** skewed features: {', '.join(skewed) or 'none'}; absolute correlation ≥0.90 pairs: " +
                         (", ".join(f"{x}/{y} ({v:+.2f})" for x,y,v in pairs) if pairs else "none") +
                         f"; gap missing for {gap_null:,} customers (one-order history).")

    report=f'''# Phase 10: Machine Learning Feasibility for 365-Day Observed Non-Return

## Decision

**C) More historical data or better business definitions are required before credible prediction.** The diagnostic models can rank or classify these historical labels to varying degrees, but the data contain only two sharply different regimes, no representative future evaluation window, substantial cross-snapshot identity overlap, and a noisy 365-day non-return target. This phase does not support deployment or a claim of permanent churn prediction.

## Objective and target

Assess whether cutoff-safe customer features contain useful signal for `AnalyticalChurn=1` (no observed order in the fully observed 365 days after cutoff). `AnalyticalChurn=0` means at least one observed return. “Non-return” is limited to that window; later return remains possible.

## Populations and validation

| Snapshot | Cutoff | Customers | Non-return (positive class) | Return | Non-return prevalence |
|---|---|---:|---:|---:|---:|
| A_2012 | 2012-06-30 | {len(a):,} | {int(a.AnalyticalChurn.sum()):,} | {int((a.AnalyticalChurn==0).sum()):,} | {rate(a.AnalyticalChurn.mean())} |
| B_2013 | 2013-06-30 | {len(b):,} | {int(b.AnalyticalChurn.sum()):,} | {int((b.AnalyticalChurn==0).sum()):,} | {rate(b.AnalyticalChurn.mean())} |

The SQL result has exactly one row per snapshot/customer, and the counts reconcile to Phase 8/9. The outcome alone reads the following year. Predictor orders are restricted to on/before cutoff. There are no monetary inputs.

## Feature and leakage audit

The small diagnostic feature list is: **{', '.join(FEATURES)}**. `AverageDaysBetweenOrders` is missing when a customer has only one pre-cutoff order. The training-fold median imputer adds a missingness indicator; it does not overwrite the source analysis table. Scaling for logistic regression is fit inside each training fold.

Explicit exclusions:

- `AnalyticalChurn`, return-window fields, and any post-cutoff order features: target/outcome leakage.
- RF quantile scores and RF segments: snapshot-wide cut points depend on the eligible cohort, so excluded from this conservative experiment.
- `CustomerStructure`: `Sales.Customer` is not effective-dated, so current Person/Store linkage is not proven historical.
- Product/category features and dominant category: current product hierarchy is not effective-dated; excluded from the core comparison.
- First/last `OnlineOrderFlag`: excluded because Phase 9 data checks found these flags almost perfectly redundant with each other and `OnlineOrderShare`; the share is retained as the single channel summary.
- Monetary features (`SubTotal`, prices, line totals, AOV, monetary score): excluded pending currency resolution.
- `CustomerLifetimeDays`: omitted because it is algebraically determined by `DaysSinceFirstOrder` minus `RecencyDays`; one-order/repeat is represented by Frequency rather than adding a redundant binary field.

The SQL feature query is the Phase 9 read-only `sql/09_statistics/01_statistical_dataset.sql`. The extract-specific acquisition boundary and current hierarchy caveats remain.

### Quality, missingness, skew, and redundancy

{quality_table}

{chr(10).join(corr_text)}

Frequency and order gaps are discrete/heavy-tailed; online shares and binary flags are bounded. Any observed feature redundancy is listed above and should temper coefficient interpretation. Correlation checks are descriptive and do not prove conditional independence.

## Evaluation design

Within each snapshot, each customer appears once. Five-fold stratified CV uses fixed seed **{SEED}** and creates out-of-fold predictions for every customer. Customer IDs are checked for train/test intersection in every fold. The full preprocessing/model pipeline is fit independently on each training fold. This is a **stratified diagnostic split within historical data, not temporal validation**. A future prospective test is unavailable, and the July 2013 break makes representative forward performance unknown.

Models are deliberately minimal: L2-regularized Logistic Regression (`C=1`, liblinear) and Random Forest (250 trees, minimum leaf size 5, square-root feature sampling). No extensive tuning was performed. Positive class throughout is **365-day analytical non-return (1)**.

ROC-AUC is threshold-independent ranking; PR-AUC is average precision and should be compared with the listed target prevalence. Precision, recall, F1, balanced accuracy, and confusion counts use the stated probability threshold. Brier score uses probabilities and is lower when probability forecasts are better. AUC and other scores are diagnostic estimates on these historical samples only.

## Baselines and model results

Majority-class baseline predicts the most common label and uses prevalence as its constant probability only for Brier scoring. The common rule baseline predicts non-return for customers with exactly one order so far. This rule is intentionally unchanged between snapshots; Phase 9 showed that its relationship reverses, so it is illustrative rather than a tuned targeting policy. For the rule, its deterministic 0/1 scores support ranking metrics and Brier calculation but are not calibrated probabilities.

{summary_table}

`TN/FP/FN/TP` use return/non-return as labels 0/1. Because A is 83.7% positive and B only 16.9% positive, baseline accuracy would be misleading. The rule's performance shift between snapshots is evidence of regime sensitivity, not a stable decision rule.

### Selected thresholds

Thresholds 0.10, 0.20, and 0.50 are shown to expose the precision/recall tradeoff. No threshold is selected as a business operating point; intervention costs and capacity were not provided.

{threshold_table}

### Calibration

The calibration figure compares predicted probability bins to observed non-return rates. The table provides each bin's sample size, mean predicted probability, and observed rate. These are in-sample-period OOF calibration diagnostics and can be noisy in the tails; no recalibration was applied.

![Out-of-fold calibration by snapshot](figures/10_calibration.png)

{calibration_table_text}

## Descriptive feature importance and instability

The following coefficients/importances are refits on the full snapshot **for description only**, not performance evaluation. Logistic coefficients are standardized-feature log-odds coefficients; Random Forest values are impurity importance and can favor correlated features. Neither is causal evidence.

{importance_text}

Phase 9 established reversals in recency, frequency, repeat status, channel share, and product mix. This feasibility run reinforces that single-regime associations cannot be assumed stable. The snapshot-specific coefficients and importances are descriptive; the small samples/regime shift make direct rank comparisons provisional.

## Cross-regime A→B stress test

The two eligible populations share **{overlap_count:,} customer IDs ({rate(overlap_rate)} of B)**; A-to-B model training and evaluation therefore reuses identities. B rows contain later updated histories, but the feature definitions are cutoff-safe at each respective cutoff. The preprocessing and model are fit only on A, then applied to B without refitting. Results are **exploratory stress-test results, not an independent prospective holdout**.

{stress_text}

The all-B stress ROC-AUC is {fmt(metrics[(metrics.experiment=="A_to_B stress (all B; overlap allowed)") & (metrics.model=="Regularized Logistic Regression") & np.isclose(metrics.threshold,.5)].roc_auc.iloc[0])} for Logistic Regression and {fmt(metrics[(metrics.experiment=="A_to_B stress (all B; overlap allowed)") & (metrics.model=="Random Forest") & np.isclose(metrics.threshold,.5)].roc_auc.iloc[0])} for Random Forest, versus within-B diagnostic ROC-AUCs of {fmt(metrics[(metrics.experiment=="B_2013") & (metrics.model=="Regularized Logistic Regression") & np.isclose(metrics.threshold,.5)].roc_auc.iloc[0])} and {fmt(metrics[(metrics.experiment=="B_2013") & (metrics.model=="Random Forest") & np.isclose(metrics.threshold,.5)].roc_auc.iloc[0])}. The A-trained models produce many false positive non-return flags in B, which is consistent with serious regime sensitivity. The nonoverlap subgroup results do not repair the evaluation design or establish representative forward generalization.

The B-nonoverlap subgroup is included only if present and large enough to calculate metrics. All B, overlap-only, and nonoverlap-only rows are distinguished in the CSV. Small subgroup AUCs may be undefined if only one label occurs.

## Practical interpretation and limitations

The experiments show whether cutoff-safe history can distinguish these historical labels inside each regime, but they cannot establish future deployment value. The 365-day rule may classify customers who return later as non-returners, the regimes have very different prevalences, and RF segmentation may offer a simpler descriptive route while business definitions are clarified. A performance result here does not justify intervention, causal claims, ROI, or a production churn designation.

The chosen model set is intentionally small. Customer structure and current product hierarchy are excluded from modeling because their historical stability is unknown. No credentials are logged or saved. AdventureWorks was queried with SELECT-only SQL and was not modified. Seeds and parameters are fixed in code; requirements already include pandas, NumPy, scikit-learn, and matplotlib, so no dependency update was needed.

## Recommendation

**Decision C: More historical data or better business definitions are required before credible prediction.** Continue descriptive segmentation and data-quality/business-definition work while seeking more time periods with stable feature semantics and a representative forward test. A limited experiment has been completed for feasibility, but neither this experiment nor its cross-regime stress test is a valid production-readiness assessment. Do not proceed to Power BI publication or production ML automatically.
'''
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(report, encoding="utf-8")
    print(f"Validated {len(df):,} rows; wrote {REPORT.name} and {METRICS_PATH.name}")


if __name__ == "__main__":
    main()
