"""Leakage-conscious preprocessing for Phase 10 feasibility experiments."""
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier


# All values are recomputed from orders on or before that row's cutoff.
# CustomerLifetimeDays is omitted because it is algebraically determined by
# RecencyDays and DaysSinceFirstOrder. RF scores are cohort-quantile features;
# current customer structure and current product hierarchy are excluded.
FEATURES = [
    "RecencyDays",
    "Frequency",
    "DaysSinceFirstOrder",
    "OnlineOrderShare",
    "AverageDaysBetweenOrders",
]

SEED = 91026


def build_pipeline(model_kind: str, seed: int = SEED):
    """Build a fold-local imputation/scaling/model pipeline.

    Missing average purchase gaps are retained as missing in source data.
    The imputer is fit on each training fold and adds a missingness indicator.
    """
    steps = [("imputer", SimpleImputer(strategy="median", add_indicator=True))]
    if model_kind == "logistic":
        steps.append(("scaler", StandardScaler()))
        estimator = LogisticRegression(
            C=1.0, solver="liblinear", max_iter=2000,
            random_state=seed,
        )
    elif model_kind == "random_forest":
        estimator = RandomForestClassifier(
            n_estimators=250, min_samples_leaf=5, max_features="sqrt",
            class_weight=None, n_jobs=-1, random_state=seed,
        )
    else:
        raise ValueError(f"Unknown model kind: {model_kind}")
    from sklearn.pipeline import Pipeline as ModelPipeline
    return ModelPipeline([("preprocess", Pipeline(steps)), ("model", estimator)])


def transformed_feature_names(fitted_pipeline):
    """Return names for the imputed and optionally scaled design matrix."""
    return fitted_pipeline.named_steps["preprocess"].named_steps["imputer"].get_feature_names_out(FEATURES)
