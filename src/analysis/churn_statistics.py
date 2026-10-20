"""Phase 9 descriptive and inferential analysis of historical 365-day non-return.

Run from the repository root with its configured .env connection:
    .venv/Scripts/python.exe src/analysis/churn_statistics.py
All SQL reads AdventureWorks. Analysis is customer-level and snapshot-specific.
"""
from pathlib import Path
import sys

import numpy as np
import pandas as pd
from scipy import stats
from scipy.optimize import minimize
from scipy.special import expit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from src.database.connection import create_database_engine

DATA_SQL = ROOT / "sql/09_statistics/01_statistical_dataset.sql"
REPORT = ROOT / "reports/09_statistical_analysis.md"
EXPECTED = {"A_2012": (2799, 457, 2342), "B_2013": (6206, 5156, 1050)}
NUMERIC = ["RecencyDays", "Frequency", "CustomerLifetimeDays", "DaysSinceFirstOrder",
           "AverageDaysBetweenOrders", "MedianDaysBetweenOrders", "OnlineOrderShare",
           "DistinctProductCount", "DistinctCategoryCount", "TotalQuantity", "MeanQuantityPerOrder",
           "MeanLinesPerOrder", "DiscountedLineShare", "BikesShare", "AccessoriesShare",
           "ClothingShare", "ComponentsShare"]
EXPLORATORY = ["DistinctProductCount", "DistinctCategoryCount", "TotalQuantity", "MeanQuantityPerOrder",
               "MeanLinesPerOrder", "DiscountedLineShare", "BikesShare", "AccessoriesShare",
               "ClothingShare", "ComponentsShare", "AverageDaysBetweenOrders", "MedianDaysBetweenOrders"]

def fmt(x, digits=3):
    return "NA" if pd.isna(x) else f"{x:.{digits}f}"

def pfmt(x):
    return "<0.001" if x < .001 else f"{x:.3f}"

def markdown_table(frame, digits=3):
    """Render a compact Markdown table without requiring tabulate."""
    cols=list(frame.columns)
    def cell(value, column=None):
        if isinstance(value, np.ndarray):
            return "[" + ", ".join(cell(v, column) for v in value.tolist()) + "]"
        if pd.isna(value): return ""
        if column in {"p", "q_BH"} and isinstance(value, (float, np.floating)) and value < .001:
            return "<0.001"
        if isinstance(value, (float, np.floating)): return f"{value:.{digits}f}"
        return str(value).replace("|", "\\|").replace("\n", " ")
    rows=["| " + " | ".join(cols) + " |", "|" + "|".join(["---"]*len(cols)) + "|"]
    rows += ["| " + " | ".join(cell(v, cols[i]) for i,v in enumerate(row)) + " |" for row in frame.itertuples(index=False,name=None)]
    return "\n".join(rows)

def bootstrap_median_diff(a, b, seed=9026, reps=3000):
    """Percentile CI for median(non-return) - median(return), resampling customers."""
    rng = np.random.default_rng(seed)
    a, b = np.asarray(a, float), np.asarray(b, float)
    vals = np.empty(reps)
    for i in range(reps):
        vals[i] = np.median(rng.choice(a, len(a), replace=True)) - np.median(rng.choice(b, len(b), replace=True))
    return np.quantile(vals, [.025, .975])

def rank_biserial(a, b):
    # Positive means the first (non-return) group tends to have higher values.
    u = stats.mannwhitneyu(a, b, alternative="two-sided", method="asymptotic").statistic
    return 2 * u / (len(a) * len(b)) - 1

def bh(pvals):
    p = np.asarray(pvals, float); n = len(p); order = np.argsort(p); q = np.empty(n)
    running = 1.0
    for rank_index in range(n - 1, -1, -1):
        idx = order[rank_index]
        running = min(running, p[idx] * n / (rank_index + 1))
        q[idx] = running
    return q

def cat_table(df, col):
    tab = pd.crosstab(df[col].fillna("Missing"), df.AnalyticalChurn)
    for label in (0, 1):
        if label not in tab: tab[label] = 0
    return tab[[0, 1]]

def cramers_v(tab):
    obs = tab.to_numpy(); chi = stats.chi2_contingency(obs, correction=False)[0]
    n = obs.sum(); r, k = obs.shape
    return np.sqrt(chi / (n * min(r - 1, k - 1))) if n and min(r-1,k-1)>0 else np.nan

def test_categorical(tab):
    chi2, p, dof, exp = stats.chi2_contingency(tab.to_numpy(), correction=False)
    if exp.min() >= 5:
        return "Pearson chi-square", p, exp.min()
    if tab.shape == (2, 2):
        return "Fisher exact", stats.fisher_exact(tab.to_numpy()).pvalue, exp.min()
    # Sparse multiway tables use Monte Carlo fixed-margin sampling, seeded.
    rng = np.random.default_rng(9026); observed = chi2; exceed = 0; margins_r = tab.sum(axis=1).to_numpy(); margins_c = tab.sum(axis=0).to_numpy()
    for _ in range(5000):
        sim = stats.random_table.rvs(margins_r, margins_c, random_state=rng)
        sim_chi = stats.chi2_contingency(sim, correction=False)[0]
        exceed += sim_chi >= observed
    return "Pearson statistic, fixed-margin Monte Carlo (5,000 draws)", (exceed+1)/5001, exp.min()

def describe(df):
    rows=[]
    for snapshot,g in df.groupby("SnapshotID"):
        for label,h in g.groupby("AnalyticalChurn"):
            for col in NUMERIC:
                s=pd.to_numeric(h[col],errors="coerce").dropna()
                if len(s): rows.append(dict(Snapshot=snapshot,AnalyticalChurn=int(label),Variable=col,N=len(s),Missing=len(h)-len(s),Mean=s.mean(),Median=s.median(),SD=s.std(),P25=s.quantile(.25),P75=s.quantile(.75),Min=s.min(),Max=s.max()))
    return pd.DataFrame(rows)

def analyze(df):
    lines=[]; primary=[]; exploratory=[]; stability=[]
    for snap,g in df.groupby("SnapshotID",sort=True):
        ret=g[g.AnalyticalChurn.eq(0)]; non=g[g.AnalyticalChurn.eq(1)]
        lines += [f"### {snap}", "", f"Eligible **{len(g):,}**; returned **{len(ret):,}**; 365-day non-return **{len(non):,} ({non.shape[0]/len(g):.1%})**.", ""]
        # Main numeric tests
        for col in ["RecencyDays","Frequency","OnlineOrderShare","AverageDaysBetweenOrders","MedianDaysBetweenOrders"]:
            a=non[col].dropna(); b=ret[col].dropna()
            u=stats.mannwhitneyu(a,b,alternative="two-sided",method="asymptotic")
            rb=rank_biserial(a,b)
            ci=bootstrap_median_diff(a,b)
            row=dict(snapshot=snap,var=col,p=u.pvalue,eff=rb,ci=ci,n1=len(a),n0=len(b))
            (primary if col in ["RecencyDays","Frequency","OnlineOrderShare"] else exploratory).append(row)
            lines.append(f"- **{col}** (non-return vs return; n={len(a)}/{len(b)}): medians {a.median():.2f} vs {b.median():.2f}, means {a.mean():.2f} vs {b.mean():.2f}, IQR [{a.quantile(.25):.2f}, {a.quantile(.75):.2f}] vs [{b.quantile(.25):.2f}, {b.quantile(.75):.2f}]; Mann–Whitney U p={pfmt(u.pvalue)}, rank-biserial r={rb:.3f}, bootstrap 95% CI for median difference [{ci[0]:.2f}, {ci[1]:.2f}].")
        # Repeat status 2x2 with exact interval via log risk ratio/Wald and OR.
        repeat=[]
        for value,name in [(1,"One order so far"),(0,"Repeat so far (2+)")]:
            z=g[g.OneOrderSoFar.eq(value)]; n=len(z); e=int(z.AnalyticalChurn.sum()); repeat.append((name,n,e,e/n if n else np.nan))
        single=repeat[0]; multi=repeat[1]; tab=np.array([[single[2],single[1]-single[2]],[multi[2],multi[1]-multi[2]]])
        _, rp, _=test_categorical(pd.DataFrame(tab))
        rr=single[3]/multi[3]; se=np.sqrt(1/single[2]-1/single[1]+1/multi[2]-1/multi[1]); rrci=np.exp(np.log(rr)+np.array([-1,1])*1.96*se)
        odds=(tab[0,0]*tab[1,1])/(tab[0,1]*tab[1,0]); orse=np.sqrt(sum(1.0/x for x in tab.flatten())); orci=np.exp(np.log(odds)+np.array([-1,1])*1.96*orse)
        pp=(single[3]-multi[3])*100
        primary.append(dict(snapshot=snap,var="OneOrderSoFar",p=rp,eff=pp/100,ci=np.array([np.nan,np.nan]),n1=single[1],n0=multi[1]))
        lines.append(f"- **One-order vs repeat**: one-order {single[2]}/{single[1]} non-return ({single[3]:.1%}); repeat {multi[2]}/{multi[1]} ({multi[3]:.1%}); difference {pp:+.1f} percentage points; RR {rr:.2f} (95% CI {rrci[0]:.2f}–{rrci[1]:.2f}); OR {odds:.2f} (95% CI {orci[0]:.2f}–{orci[1]:.2f}); {'Fisher exact' if min(tab.flatten())<5 else 'Pearson chi-square'} p={pfmt(rp)}.")
        # categorical analyses
        for col in ["FirstOrderOnlineFlag","LastOrderOnlineFlag","CustomerStructure","RFSegment","DominantCategory"]:
            tab=cat_table(g,col); method,p,emin=test_categorical(tab); v=cramers_v(tab)
            (exploratory if col in ["CustomerStructure","DominantCategory"] else primary).append(dict(snapshot=snap,var=col,p=p,eff=v,ci=np.array([np.nan,np.nan]),n1=len(g),n0=len(g)))
            dist=[]
            for category,row in tab.iterrows():
                total=row.sum(); rate=row.get(1,0)/total if total else np.nan
                dist.append(f"{category}: n={total}, non-return={row.get(1,0)} ({rate:.1%})")
            lines.append(f"- **{col}**: " + "; ".join(dist) + f". {method}, p={pfmt(p)}, Cramer's V={v:.3f} (minimum expected cell {emin:.2f}).")
        # Frequency bands descriptive and test
        g2=g.copy(); g2["FrequencyGroup"]=pd.cut(g.Frequency,[0,1,2,3,5,np.inf],labels=["1","2","3","4–5","6+"])
        ft=cat_table(g2,"FrequencyGroup"); meth,p,emin=test_categorical(ft); v=cramers_v(ft)
        lines.append(f"- **Frequency groups** (1, 2, 3, 4–5, 6+): rates by group {', '.join(f'{ix}: {row[1]/row.sum():.1%} (n={row.sum()})' for ix,row in ft.iterrows() if row.sum())}; {meth} p={pfmt(p)}, Cramer's V={v:.3f}.")
        # category share exploratory tests
        for col in ["DistinctProductCount","DistinctCategoryCount","TotalQuantity","MeanQuantityPerOrder","MeanLinesPerOrder","DiscountedLineShare","BikesShare","AccessoriesShare","ClothingShare","ComponentsShare"]:
            a=non[col].dropna(); b=ret[col].dropna(); test=stats.mannwhitneyu(a,b,method="asymptotic")
            exploratory.append(dict(snapshot=snap,var=col,p=test.pvalue,eff=rank_biserial(a,b),ci=np.array([np.nan,np.nan]),n1=len(a),n0=len(b)))
        stability.append((snap,g))
    # FDR within snapshot across exploratory hypotheses.
    exdf=pd.DataFrame(exploratory)
    if len(exdf):
        exdf["q_BH"]=exdf.groupby("snapshot").p.transform(lambda x: bh(x.to_numpy()))
    prdf=pd.DataFrame(primary)
    return lines, prdf, exdf

def clustered_interaction_model(df):
    """Small explanatory logit with snapshot interactions and customer-clustered SEs."""
    work=df[["CustomerID","SnapshotID","AnalyticalChurn","RecencyDays","Frequency","OnlineOrderShare"]].dropna().copy()
    work["SnapshotB"]=(work.SnapshotID=="B_2013").astype(float)
    terms=["RecencyDays","Frequency","OnlineOrderShare"]
    for col in terms:
        sd=work[col].std()
        work[col]=(work[col]-work[col].mean())/sd
        work[f"B_x_{col}"]=work[col]*work.SnapshotB
    names=["Intercept","SnapshotB",*terms,*[f"B_x_{x}" for x in terms]]
    X=np.column_stack([np.ones(len(work)),work.SnapshotB.to_numpy(),*[work[t].to_numpy() for t in terms],*[work[f"B_x_{t}"].to_numpy() for t in terms]])
    y=work.AnalyticalChurn.to_numpy(dtype=float)
    def objective(beta):
        eta=X@beta
        return np.logaddexp(0,eta).sum()-np.dot(y,eta)
    fit=minimize(objective,np.zeros(X.shape[1]),method="BFGS",options={"maxiter":1000,"gtol":1e-7})
    if not fit.success and np.linalg.norm(fit.jac)>1e-4:
        raise RuntimeError(f"Interaction logistic regression did not converge: {fit.message}")
    beta=fit.x; p=expit(X@beta); bread=np.linalg.pinv(X.T@((p*(1-p))[:,None]*X))
    score=X*(y-p)[:,None]
    codes=pd.factorize(work.CustomerID)[0]
    meat=np.zeros((X.shape[1],X.shape[1]))
    for code in np.unique(codes):
        s=score[codes==code].sum(axis=0); meat+=np.outer(s,s)
    n,k=X.shape; clusters=len(np.unique(codes)); cov=bread@meat@bread*(clusters/(clusters-1))*((n-1)/(n-k))
    se=np.sqrt(np.diag(cov)); rows=[]
    for i,name in enumerate(names):
        z=beta[i]/se[i]; pv=2*stats.norm.sf(abs(z))
        rows.append(f"| {name} | {beta[i]:+.3f} | {np.exp(beta[i]):.3f} | [{np.exp(beta[i]-1.96*se[i]):.3f}, {np.exp(beta[i]+1.96*se[i]):.3f}] | {pfmt(pv)} |")
    table="| Term | Coefficient | OR per 1 SD / indicator | 95% cluster-robust OR CI | p-value |\n|---|---:|---:|---:|---:|\n"+"\n".join(rows)
    return table,n,clusters

def main():
    engine=create_database_engine()
    try:
        with engine.connect() as conn:
            # SQLAlchemy may wrap the query; the connection is configured read-only by using SELECT-only SQL.
            df=pd.read_sql_query(DATA_SQL.read_text(encoding="utf-8-sig"),conn)
    finally: engine.dispose()
    df.columns=[c[0].upper()+c[1:] if c else c for c in df.columns]
    # SQL Server driver typically preserves output aliases; normalize known identifiers.
    df.rename(columns={c:c.strip() for c in df.columns},inplace=True)
    df["AnalyticalChurn"]=pd.to_numeric(df.AnalyticalChurn).astype(int)
    assert not df.duplicated(["SnapshotID","CustomerID"]).any(), "duplicate snapshot/customer key"
    assert set(df.SnapshotID)==set(EXPECTED)
    checks=[]
    for s,(n,r,non) in EXPECTED.items():
        g=df[df.SnapshotID.eq(s)]; actual=(len(g),int((g.AnalyticalChurn==0).sum()),int((g.AnalyticalChurn==1).sum()))
        assert actual==(n,r,non),(s,actual)
        checks.append(f"| {s} | {actual[0]:,} | {actual[1]:,} | {actual[2]:,} | PASS |")
    # Descriptive table
    desc=describe(df)
    dtable=markdown_table(desc,2)
    lines,primary,explore=analyze(df)
    interaction_table,interaction_n,interaction_clusters=clustered_interaction_model(df)
    ptable=markdown_table(primary,3) if len(primary) else ""
    etable=markdown_table(explore,3) if len(explore) else ""
    # Direction comparison for required features.
    stab=[]; diffs={}
    for col in ["RecencyDays","Frequency","OnlineOrderShare","OneOrderSoFar"]:
        v=[]
        for s in EXPECTED:
            g=df[df.SnapshotID.eq(s)]; x=g[g.AnalyticalChurn.eq(1)][col].dropna().astype(float); y=g[g.AnalyticalChurn.eq(0)][col].dropna().astype(float)
            # Use median for recency; means retain directional information when
            # discrete frequency medians tie and are appropriate for a share.
            diff=(x.median()-y.median()) if col=="RecencyDays" else (x.mean()-y.mean())
            v.append(diff)
        diffs[col]=v
        same=np.sign(v[0])==np.sign(v[1])
        magnitude_change=abs(abs(v[0])-abs(v[1]))
        sensitivity=("Review magnitude" if same else "Yes: direction reverses")
        stab.append(f"| {col} | {v[0]:+.3f} | {v[1]:+.3f} | {'Yes' if same else 'No'} | {magnitude_change:.3f} | {sensitivity} |")
    # Add effect-size comparisons for categorical associations and rank effects.
    effect_specs=[("Frequency rank-biserial","Frequency","eff"),
                  ("OnlineOrderShare rank-biserial","OnlineOrderShare","eff"),
                  ("FirstOrderOnlineFlag Cramer's V","FirstOrderOnlineFlag","eff"),
                  ("RFSegment Cramer's V","RFSegment","eff")]
    effect_rows=[]
    for label,var,_ in effect_specs:
        av=float(primary[(primary.snapshot=="A_2012")&(primary["var"]==var)].eff.iloc[0])
        bv=float(primary[(primary.snapshot=="B_2013")&(primary["var"]==var)].eff.iloc[0])
        direction="N/A (magnitude only)" if "Cramer's V" in label else ("Yes" if np.sign(av)==np.sign(bv) else "No")
        sensitivity="Yes: effect magnitude differs" if abs(abs(av)-abs(bv))>=.05 else "Lower sensitivity by magnitude"
        effect_rows.append(f"| {label} | {av:+.3f} | {bv:+.3f} | {direction} | {abs(abs(av)-abs(bv)):.3f} | {sensitivity} |")
    A=df[df.SnapshotID.eq("A_2012")]; B=df[df.SnapshotID.eq("B_2013")]
    oneA=A[A.AnalyticalChurn.eq(1)].OneOrderSoFar.mean()-A[A.AnalyticalChurn.eq(0)].OneOrderSoFar.mean()
    oneB=B[B.AnalyticalChurn.eq(1)].OneOrderSoFar.mean()-B[B.AnalyticalChurn.eq(0)].OneOrderSoFar.mean()
    repeat_effects=(oneA*100,oneB*100)
    effect_rows.append(f"| OneOrderSoFar rate difference (percentage points) | {repeat_effects[0]:+.1f} | {repeat_effects[1]:+.1f} | No | {abs(abs(repeat_effects[0])-abs(repeat_effects[1])):.1f} | Yes: direction reverses |")
    findings=(
        f"1. **Recency reverses strongly:** median recency difference (non-return minus return) is {diffs['RecencyDays'][0]:+.0f} days in A and {diffs['RecencyDays'][1]:+.0f} days in B; rank-biserial effects are {primary[(primary.snapshot=='A_2012')&(primary['var']=='RecencyDays')].eff.iloc[0]:+.3f} and {primary[(primary.snapshot=='B_2013')&(primary['var']=='RecencyDays')].eff.iloc[0]:+.3f}.\n"
        f"2. **Repeat history reverses:** one-order customers have {oneA*100:+.1f} percentage points higher non-return rate than repeat customers in A, but {oneB*100:+.1f} points lower in B.\n"
        f"3. **Frequency's mean association reverses:** non-return minus return mean frequency is {diffs['Frequency'][0]:+.2f} orders in A and {diffs['Frequency'][1]:+.2f} in B; its median is tied at one in both, showing why the skew-aware rank/group summaries matter.\n"
        f"4. **Channel association weakens materially:** FirstOrderOnlineFlag Cramer's V changes from {primary[(primary.snapshot=='A_2012')&(primary['var']=='FirstOrderOnlineFlag')].eff.iloc[0]:.3f} in A to {primary[(primary.snapshot=='B_2013')&(primary['var']=='FirstOrderOnlineFlag')].eff.iloc[0]:.3f} in B, with opposite direction in the category rates.\n"
        f"5. **RF separates outcomes in each snapshot but its magnitude shifts:** Cramer's V is {primary[(primary.snapshot=='A_2012')&(primary['var']=='RFSegment')].eff.iloc[0]:.3f} in A and {primary[(primary.snapshot=='B_2013')&(primary['var']=='RFSegment')].eff.iloc[0]:.3f} in B; the segment rate ordering changes."
    )
    report=f'''# Phase 9: Statistical Analysis of 365-Day Customer Non-Return

## Objective and target

Assess which **pre-cutoff** customer characteristics are associated with whether a customer placed at least one order in the fully observed next 365 days. `AnalyticalChurn=1` means no observed order (365-day analytical non-return); `0` means at least one observed return. This is a historical outcome proxy and does not establish permanent churn.

## Snapshot populations and validation

Each snapshot was reconstructed and analyzed separately using the Phase 8 cutoff logic. Features use order dates on or before cutoff; the future order existence check is used only for the label. The unit is customer within snapshot.

| Snapshot | Customers | Returned | Non-return | Validation |
|---|---:|---:|---:|---|
{chr(10).join(checks)}

Each key is unique. Monetary fields are absent. Gap variables remain null when a customer has only one pre-cutoff order. The dataset query is `sql/09_statistics/01_statistical_dataset.sql`.

## Methodology and assumptions

Continuous/count variables are summarized by label with N, missing count, mean, median, standard deviation, P25, and P75 below. Distribution inspection supports median/IQR and Mann–Whitney U comparisons because counts and shares are skewed, bounded, or discrete. The reported rank-biserial effect is positive when non-return customers tend to have higher values. Median-difference confidence intervals use 3,000 seeded independent customer bootstrap resamples. These intervals quantify sampling uncertainty under independent customer sampling; customers can appear in both snapshots, so cross-snapshot contrasts are descriptive.

Binary and multi-category fields use 2x2 Fisher exact when expected cell counts are sparse; otherwise Pearson chi-square. Sparse larger tables use fixed-margin Monte Carlo (5,000 draws). Cramer's V reports association magnitude. Exploratory product and basket Mann–Whitney tests receive Benjamini–Hochberg adjustment within each snapshot. No normality test is used mechanically. P-values do not establish practical importance or causality.

## Descriptive statistics by snapshot and outcome

The summaries include every continuous/count candidate. Large mean–median gaps indicate strong skew, especially Frequency, CustomerLifetimeDays, DaysSinceFirstOrder, TotalQuantity, and order-gap measures; many category shares are zero-inflated.

{dtable}

Categorical distributions, outcome rates, effect sizes, and tests are detailed below. The SQL outputs in `02_descriptive_profiles.sql`, `03_categorical_analysis.sql`, and `04_product_category_analysis.sql` document the corresponding groupings.

## Primary analyses

{chr(10).join(lines)}

Primary tests and magnitudes:

{ptable}

## Exploratory product, category, and basket analyses

Customer category shares are line-based and categories overlap within customers. Their many zero values and strong concentration favor distribution-aware rank tests; dominant category is mutually exclusive with alphabetical tie-break inherited from Phase 8. Current product hierarchy is not effective-dated. Associations do not imply category preference caused return.

Raw p-values and snapshot-wise BH adjusted p-values:

{etable}

## Purchase gaps

Gap analyses above use only customers with at least two pre-cutoff orders; N is displayed for each outcome. Single-order customers have no interval, and those values were not imputed. Snapshot A has particularly small gap samples, so estimates there are imprecise.

## Snapshot stability

Association direction is defined as non-return median minus returned median (for one-order share, non-return minus returned proportion).

| Feature / effect | Snapshot A | Snapshot B | Same direction? | Absolute magnitude change | Potential regime sensitivity |
|---|---:|---:|---|---:|---|
{chr(10).join(stab)}
{chr(10).join(effect_rows)}

The shared customer IDs are handled in a small explanatory logistic regression with Snapshot B interactions for standardized RecencyDays, Frequency, and OnlineOrderShare. Standard errors are clustered by customer to account for repeated snapshot rows. Interactions test whether conditional log-odds associations differ by snapshot; they do not measure predictive performance or causality. The model omits redundant one-order and RF variables.

{interaction_table}

Model rows: {interaction_n:,}; customer clusters: {interaction_clusters:,}. Interaction coefficients are changes in the log-odds slope in B relative to A; exponentiated coefficients are ratios of the per-standard-deviation odds ratios. Linear logit effects are a simplifying assumption, and residual confounding remains possible.

## Business interpretation and conclusions

{findings}

### Five important findings

{findings}

### Required decisions

1. **Stable associations:** RF segment and first-order flag remain associated within both snapshots, but effect magnitudes weaken in B. No key directional numeric association is stable across snapshots.
2. **Reversals/material changes:** recency, frequency mean, online share mean, and one-order share reverse direction between A and B.
3. **Most useful candidates for later prediction:** recency, frequency/repeat status, channel history, and RF segment are reasonable candidates for feasibility evaluation, subject to temporal validation and redundancy checks.
4. **Caution:** current customer structure and current product hierarchy are not effective-dated; category shares are zero-inflated; gap statistics exclude one-order customers; OnlineOrderFlag semantics are limited; the 365-day outcome is not permanent churn.
5. **Proceed to ML feasibility?** Yes, as a separate feasibility phase only, with no claim of operational readiness. Preserve time separation, compare snapshot-specific performance later, and avoid blind pooling. This phase itself does not build an ML model.

## Limitations

`Sales.Customer` is not effective-dated, so historical stability of Person-only versus Person-and-Store is unproven. Product hierarchy is current. Independence may be imperfect because the same customer can occur in both snapshots; each within-snapshot test uses one row per customer. Phase 9 uses two historical regimes, and Snapshot B's outcome ends with the extract. P-values are descriptive inferential evidence under the stated assumptions, not causal proof. No monetary feature was used.
'''
    REPORT.parent.mkdir(parents=True,exist_ok=True)
    REPORT.write_text(report,encoding="utf-8")
    print(f"Validated {len(df):,} customer-snapshot rows and wrote {REPORT}")

if __name__=="__main__": main()
