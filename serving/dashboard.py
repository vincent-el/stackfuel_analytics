"""Training Operations Dashboard: the five answers (Überblick) and the Handlungsbedarf lists.

Thin: every number comes from a serving/questions or serving/worklists SQL file over a mart
function; the page selects rows, sums cells and divides (share), takes a mean over returned rows,
and subtracts the previous week's reading from the Stichtag's for a delta. Nothing else is
computed here. Time model: the Stichtag is the one date every query reads, the state
at the end of that day; the sidebar holds only what applies to every block, the rest sits in the
block it changes.
Run from the repo root: make dashboard (uv run streamlit run serving/dashboard.py).
"""

from datetime import timedelta
from pathlib import Path

import altair as alt
import duckdb
import pandas as pd
import streamlit as st
from answers import DEFAULTS, QUESTIONS, WAREHOUSE, data_as_of, run

WORKLISTS = Path(__file__).parent / "worklists"
Q1, Q2, Q3, Q4, Q5 = sorted(QUESTIONS.glob("q[1-5]_*.sql"))
MIN_N = 10  # a rate on fewer answers is shown faded: same colour, not judged
LABELS = {
    "training_id": "ID", "training_name": "Training", "variant": "Variante",
    "active": "aktiv", "paused": "pausiert", "funding_type": "Förderart", "n": "n",
    "completed": "abgeschlossen", "dropped_out": "abgebrochen", "still_open": "offen",
    "completion_rate_pct": "Abschlussquote", "dropout_rate_pct": "Abbruchquote",
    "open_rate_pct": "offen (Anteil)", "cancelled": "storniert",
    "modules_completed_pct": "Lernfortschritt", "time_elapsed_within_plan_pct": "Zeitfortschritt",
    "behind_schedule": "im Verzug", "behind_schedule_pct": "Anteil im Verzug",
    "quarter": "Quartal", "promoters": "Promotoren", "passives": "Passive",
    "detractors": "Detraktoren", "nps": "NPS gesamt", "n_completed": "n Absolventen",
    "nps_completed": "NPS Absolventen", "n_dropped_out": "n Abbrecher",
    "nps_dropped_out": "NPS Abbrecher", "enrollment_id": "Teilnahme", "name": "Name",
    "email": "E-Mail", "cohort_key": "Kohorte", "schedule_gap_pp": "Rückstand (pp)",
    "sheet_row_number": "Zeile", "coach_name": "Coach", "participant_name": "Teilnehmende",
    "training_spelling": "Training (Schreibweise)", "cohort_month": "Kohortenmonat",
    "ampel": "Ampel", "data_quality_issues": "Hinweise", "stichtag": "Stichtag",
    "enrollments": "betreut", "green": "grün", "yellow": "gelb", "red": "rot",
    "ampel_missing": "ohne Ampel", "status": "Status",
}  # fmt: skip
# The columns a reader decides on, and which direction is good: +1 high is good (blue), -1 high is
# bad (red). Counts, Zeitfortschritt and offen describe and stay plain.
GOOD = {
    "completion_rate_pct": 1, "modules_completed_pct": 1, "nps": 1, "nps_completed": 1,
    "nps_dropped_out": 1, "dropout_rate_pct": -1, "behind_schedule_pct": -1,
}  # fmt: skip
BLUE, RED = "31, 119, 180", "214, 39, 40"  # the heatmap's red–blue, readable without red–green
# Q5 stacks the Ampel in the sheet's own words and colours (a count, not a judgement); grey for a
# counted line without one, darker grey for no line at all. Stack and legend in this order.
AMPEL = {"grün": "#2ca02c", "gelb": "#f0c000", "rot": f"rgb({RED})", "ohne Ampel": "#d3d3d3",
         "ohne Coach": "#8c8c8c"}  # fmt: skip
ASSETS = Path(__file__).parent / "assets"
HINTS = {
    "email_missing": "E-Mail fehlt",
    "name_reversed": "Name vertauscht (Nachname, Vorname)",
    "cohort_month_only": "Kohorte nur als Monat",
    "ampel_ambiguous": "Ampel „g“: grün oder gelb?",
    "training_spelling_unmapped": "Training-Schreibweise unbekannt",
    "duplicate_row": "zweite Zeile zur Teilnahme (ältere Ampel)",
    "match_ambiguous": "zwei Teilnahmen passen",
    "unmatched": "keine Teilnahme gefunden",
}


@st.cache_data(show_spinner=False)
def _load(sql_file: str, mtimes: tuple, params: tuple) -> pd.DataFrame:
    # cached on the warehouse's and the file's mtime: a build or an edited query refreshes it;
    # a list travels through the cache key as a tuple and back
    params = {k: list(v) if isinstance(v, tuple) else v for k, v in params}
    columns, rows = run(Path(sql_file), **params)
    return pd.DataFrame(rows, columns=columns)


@st.cache_data(show_spinner=False)
def _trainings(mtime: float) -> pd.DataFrame:
    """The sidebar's options: one row per training from the dimension (the one inline query)."""
    with duckdb.connect(str(WAREHOUSE), read_only=True) as con:
        return con.execute(
            "select training_id, training_name, variant from mart.dim_trainings order by 1"
        ).df()


@st.cache_data(show_spinner=False)
def _planned_end_quarters(reference_date, mtime: float) -> list[str]:
    """The Q2 slider's options: the planned-end quarters the function returns at the Stichtag."""
    with duckdb.connect(str(WAREHOUSE), read_only=True) as con:
        sql = "select distinct planned_end_quarter from mart.report_completion_rates(?) order by 1"
        return [row[0] for row in con.execute(sql, [reference_date]).fetchall()]


def query(sql_file: Path, **params) -> pd.DataFrame | None:
    """The file's rows, cached on params, the warehouse's and the file's mtime. With a Training/Variante
    selection, rows of other trainings are dropped where the file returns a training_id; Q5's
    rows are per coach, so the selection does not apply there (its block says so)."""
    mtimes = (WAREHOUSE.stat().st_mtime, sql_file.stat().st_mtime)
    df = _load(str(sql_file), mtimes, tuple(sorted(params.items())))
    if FILTERED and "training_id" in df:
        df = df[df.training_id.isin(SHOWN)]
    return df.reset_index(drop=True)


def share(df: pd.DataFrame, numerator: str, denominator: str) -> float | None:
    total = df[denominator].sum()
    return round(100 * df[numerator].sum() / total, 1) if total else None


def ohne_coach(df: pd.DataFrame) -> int:
    return int(df.loc[df.coach_name == "ohne Coach", "enrollments"].sum())


def nps(df: pd.DataFrame) -> float | None:
    total = df.n.sum()
    return round(100 * (df.promoters.sum() - df.detractors.sum()) / total) if total else None


def card(label, value, before=None, inverse=False, unit="", delta_unit=None, help=None):
    """st.metric with the delta against the previous week's reading. The label leads with the
    question's number in brackets and stays short (a long label is cut); the window a card reads
    goes into help, its block names it in full."""
    delta, color, arrow = None, "inverse" if inverse else "normal", "auto"
    if value is not None and before is not None:
        change = value - before
        if change == 0:  # unchanged: grey, no arrow (a "+0" would be judged)
            delta, color, arrow = "±0", "off", "off"
        else:
            delta = f"{change:+.1f}" if isinstance(change, float) else f"{change:+d}"
        delta += f"{delta_unit or unit} vs. Vorwoche"
    shown = "–" if value is None else (f"{value:.1f}{unit}" if isinstance(value, float) else value)
    st.metric(label, shown, delta, delta_color=color, delta_arrow=arrow, border=True, help=help)


def block(sql_file: Path, caption: str, zeitbezug: str, count: int | None = None):
    """Bordered container: the file's question verbatim as heading, one caption line and the
    Zeitbezug (the date the numbers read) below."""
    question = []
    for line in sql_file.read_text().splitlines():
        question.append(line.removeprefix("-- "))
        if line.endswith("?"):
            break
    box = st.container(border=True)
    box.markdown(f"#### {' '.join(question)}" + ("" if count is None else f" · {count}"))
    box.caption(f"{caption}  \n**Zeitbezug:** {zeitbezug}")
    return box


def table(df: pd.DataFrame, date_label: str | None = None, date_value: str | None = None):
    """German labels; decision columns red–blue, faded where n is below MIN_N. date_label and
    date_value become the first column, so a CSV or screenshot carries the date it reads."""
    if date_label:
        df = df.copy()
        df.insert(0, date_label, date_value)
    config = {}
    for column in df.columns:
        label = LABELS.get(column, column)
        if column.endswith("_pct"):
            config[column] = st.column_config.NumberColumn(label, format="%.1f %%")
        elif column.startswith("nps"):
            config[column] = st.column_config.NumberColumn(label, format="%d")
        elif column.endswith("_pp"):
            config[column] = st.column_config.NumberColumn(label, format="%.1f")
        elif column in ("cohort_month", "stichtag"):
            config[column] = st.column_config.DateColumn(label, format="DD.MM.YYYY")
        else:
            config[column] = st.column_config.Column(label)
    # Colour only the answers' tables (they carry n), only the decision columns.
    rates = [c for c in df.columns if c in GOOD] if "n" in df else []
    small = df.n < MIN_N if "n" in df else pd.Series(False, index=df.index)

    def shade(column: pd.Series) -> list[str]:
        # NPS on its fixed -100..100 scale; a rate within its column's own range; then the sign
        # by direction: blue is good, red is bad, the strength the distance from the middle
        if column.name.startswith("nps"):
            t = column / 100
        else:
            low, high = column.min(), column.max()
            t = 2 * (column - low) / (high - low) - 1 if high > low else column * 0
        styles = []
        for value, is_small in zip(t * GOOD[column.name], small):
            if pd.isna(value):
                styles.append("")
                continue
            alpha = abs(value) * (0.15 if is_small else 0.5)
            styles.append(f"background-color: rgba({BLUE if value > 0 else RED}, {alpha:.2f})")
        return styles

    styled = df.style.apply(shade, subset=rates) if rates else df
    st.dataframe(styled, hide_index=True, column_config=config)


def bars(df: pd.DataFrame, y: str, color: str | None = None, red: bool = False, title=None):
    """One bar per training; grouped by `color` when given; red as the one accent."""
    encoding = {
        "x": alt.X("training_id:N", title="Training"),
        "y": alt.Y(f"{y}:Q", title=title or LABELS[y]),
        "tooltip": [c for c in ("training_name", color, y, "n") if c and c in df],
    }
    if color:
        encoding["xOffset"] = alt.XOffset(f"{color}:N")
        encoding["color"] = alt.Color(f"{color}:N", title=None)
    mark = alt.Chart(df).mark_bar(color="red" if red else alt.Undefined)
    st.altair_chart(mark.encode(**encoding), width="stretch")


def coach_bars(df: pd.DataFrame, title: str):
    """One bar per coach, stacked by Ampel; ohne Coach (no line, so no Ampel) as a last grey bar."""
    no_line = df[df.coach_name == "ohne Coach"]
    parts = pd.concat([
        df.melt("coach_name", ["green", "yellow", "red", "ampel_missing"], "Ampel", "Anzahl")
          .dropna().replace({"Ampel": LABELS}),
        pd.DataFrame({"coach_name": no_line.coach_name, "Ampel": "ohne Coach",
                      "Anzahl": no_line.enrollments}),
    ])  # fmt: skip
    parts["Reihenfolge"] = parts.Ampel.map(list(AMPEL).index)
    chart = (
        alt.Chart(parts[parts.Anzahl > 0])
        .mark_bar()
        .encode(
            y=alt.Y("coach_name:N", sort=list(df.coach_name), title=None),
            x=alt.X("sum(Anzahl):Q", title=title),
            color=alt.Color(
                "Ampel:N",
                title=None,
                sort=list(AMPEL),
                scale=alt.Scale(domain=list(AMPEL), range=list(AMPEL.values())),
            ),
            order="Reihenfolge:Q",
            tooltip=[
                alt.Tooltip("coach_name", title="Coach"),
                "Ampel",
                alt.Tooltip("sum(Anzahl):Q", title="Anzahl"),
            ],
        )
    )
    st.altair_chart(chart, width="stretch")


def stacked(df: pd.DataFrame, x: str, title: str = "Anteil"):
    """Shares of abgeschlossen, offen, abgebrochen per bar."""
    columns = ["completed", "still_open", "dropped_out"]
    long = df.melt(x, columns, "Ausgang", "Anzahl")
    long["Reihenfolge"] = long.Ausgang.map(columns.index)
    long["Ausgang"] = long.Ausgang.map(LABELS)
    chart = (
        alt.Chart(long)
        .mark_bar()
        .encode(
            x=alt.X(f"{x}:N", title="Training" if x == "training_id" else LABELS[x]),
            y=alt.Y("sum(Anzahl):Q", stack="normalize", title=title, axis=alt.Axis(format="%")),
            color=alt.Color("Ausgang:N", sort=[LABELS[c] for c in columns]),
            order="Reihenfolge:Q",
            tooltip=[x, "Ausgang", "sum(Anzahl):Q"],
        )
    )
    st.altair_chart(chart, width="stretch")


def heatmap(df: pd.DataFrame):
    """Training × quarter, colour the NPS and the number in the cell; faded where n is below
    MIN_N, so a small cell keeps its direction without the weight of a judged one."""
    base = alt.Chart(df).encode(
        x=alt.X("quarter:O", title="Quartal der Abgabe"),
        y=alt.Y("training_id:N", title="Training"),
        tooltip=[
            alt.Tooltip(c, title=LABELS[c])
            for c in (
                "training_name",
                "quarter",
                "n",
                "nps",
                "n_completed",
                "nps_completed",
                "n_dropped_out",
                "nps_dropped_out",
            )
        ],
    )
    cells = base.mark_rect().encode(
        color=alt.Color(
            "nps:Q", title="NPS gesamt", scale=alt.Scale(scheme="redblue", domain=[-100, 100])
        ),
        opacity=alt.condition(f"datum.n >= {MIN_N}", alt.value(1.0), alt.value(0.35)),
    )
    numbers = base.mark_text(baseline="middle").encode(text="nps:Q")
    st.altair_chart((cells + numbers).properties(height=280), width="stretch")


# Shared frame, built once for every page. The sidebar holds only what applies to every block.
DEFAULT_STATE = {"stichtag": DEFAULTS["reference_date"], "trainings": [], "variants": []}
BLOCK_KEYS = ("pp_tempo", "pp_worklist", "q2_quarters", "q4_quarters", "q4_n")


def reset():
    """Back to the defaults: the Stichtag of the Brief, all trainings, every block control."""
    for key, value in DEFAULT_STATE.items():
        st.session_state[key] = value
    for key in BLOCK_KEYS:
        st.session_state.pop(key, None)


st.set_page_config(page_title="Training Operations Dashboard", layout="wide")
for key, value in DEFAULT_STATE.items():
    st.session_state.setdefault(key, value)
trainings = _trainings(WAREHOUSE.stat().st_mtime)
with st.sidebar:
    st.image(ASSETS / "hero.jpeg", width="stretch")
    stichtag = st.date_input("Stichtag", key="stichtag", format="DD.MM.YYYY")
    st.caption(
        "Alle Zahlen lesen den Stand am Ende dieses Tages. Bestände (aktiv, im Verzug, Betreuung) "
        "gelten an diesem Tag; Quoten und NPS zählen, was bis dahin geschehen ist."
    )
    names = st.multiselect("Training", trainings.training_name, key="trainings", placeholder="alle")
    variants = st.multiselect(
        "Variante", trainings.variant.unique(), key="variants", placeholder="alle"
    )
    st.button("↺ Zurücksetzen", on_click=reset, width="stretch")
FILTERED = bool(names or variants)
SHOWN = trainings[
    (trainings.training_name.isin(names) | (not names))
    & (trainings.variant.isin(variants) | (not variants))
].training_id
VORWOCHE = stichtag - timedelta(weeks=1)
STAND = f"{stichtag:%d.%m.%Y}"
st.title("Training Operations Dashboard")
st.caption(f"Stichtag {STAND} · Datenstand {data_as_of()}")


def schwelle(key: str) -> int:
    """The im-Verzug threshold, a control of the block that uses it."""
    return st.slider(
        "im Verzug ab … Prozentpunkten", 0, 50, DEFAULTS["behind_schedule_pp"], key=key
    )


def footer(pp: int):
    st.divider()
    st.caption(
        "aktiv, pausiert: Teilnahmen im Status am Ende des Stichtags  \n"
        "Abschlussquote = abgeschlossen / (abgeschlossen + abgebrochen + offen), geplantes Ende "
        "vor dem Stichtag  \n"
        f"im Verzug: Zeitfortschritt − Lernfortschritt ≥ {pp} pp; Anteil = im Verzug / aktive "
        "Teilnahmen  \n"
        "NPS = 100 × (Promotoren − Detraktoren) / Antworten  \n"
        f"Datenbasis: CRM, Lernplattform (LXP), Betreuungsliste · Datenstand {data_as_of()} · "
        "wöchentlicher Bericht zum Stichtag · SQL: serving/questions/, serving/worklists/"
    )
    st.image(ASSETS / "footer.png", width="stretch")


def ueberblick():
    st.sidebar.markdown(
        "**Inhalt**  \n[Bestand](#bestand) · [Tempo](#tempo) · [Betreuung](#betreuung) · "
        "[Ergebnis](#ergebnis)"
    )
    cards = st.container()  # filled last: two cards follow controls inside their blocks

    st.subheader("Bestand", anchor="bestand")
    q1 = query(Q1, reference_date=stichtag)
    with block(Q1, "Teilnahmen im Status aktiv bzw. pausiert, je Training",
               f"Status am Ende des {STAND}"):  # fmt: skip
        long = q1.melt(["training_id", "training_name"], ["active", "paused"], "Status", "Anzahl")
        long["Status"] = long.Status.map(LABELS)
        bars(long.rename(columns={"Anzahl": "n"}), "n", "Status",
             title=f"Teilnahmen, Stand {STAND}")  # fmt: skip
        with st.expander("Tabelle"):
            table(q1, "Stand am", STAND)

    st.subheader("Tempo", anchor="tempo")
    with block(Q3, "aktive Teilnahmen; Anteil im Verzug je Training",
               f"aktiv am Ende des {STAND}; Lernfortschritt aus den Ereignissen bis dahin, "
               "Zeitfortschritt ab dem Kohortenstart"):  # fmt: skip
        pp = schwelle("pp_tempo")
        q3 = query(Q3, reference_date=stichtag, behind_schedule_pp=pp)
        bars(q3, "behind_schedule_pct", red=True, title=f"Anteil im Verzug (%), Stand {STAND}")
        with st.expander("Tabelle"):
            table(q3, "Stand am", STAND)

    st.subheader("Betreuung", anchor="betreuung")
    q5 = query(Q5, reference_date=stichtag)
    with block(Q5, "aktive oder pausierte Teilnahmen je Coach laut Betreuungsliste, nach Ampel "
                   "(ohne Ampel: Zeile ohne Farbe oder mit „g“); ohne Coach als letzte Zeile",
               f"Status am Ende des {STAND}; Ampel laut Betreuungsliste, Datenstand "
               f"{data_as_of()} (die Liste hat keine Historie)"):  # fmt: skip
        if FILTERED:
            st.info("Die Auswahl Training/Variante gilt hier nicht: die Last eines Coaches geht "
                    "über alle Trainings.", icon="ℹ️")  # fmt: skip
        coach_bars(q5, f"Teilnahmen, Stand {STAND}")
        with st.expander("Tabelle"):
            table(q5, "Stand am", STAND)

    st.subheader("Ergebnis", anchor="ergebnis")
    with block(Q2, "alle Teilnahmen mit geplantem Ende im gewählten Zeitraum, storniert außerhalb "
                   "der Quoten; die jüngsten Quartale tragen mehr offen (über dem Plan, noch dabei)",
               "geplantes Ende je Quartal, vor dem Stichtag; Status am Ende des "
               f"{STAND}"):  # fmt: skip
        quarters = _planned_end_quarters(stichtag, WAREHOUSE.stat().st_mtime)
        if not set(st.session_state.get("q2_quarters", ())) <= set(quarters):
            st.session_state.pop("q2_quarters", None)  # a Stichtag change removed a quarter
        q2_from, q2_to = st.select_slider(
            "Quartale des geplanten Endes", quarters, (quarters[0], quarters[-1]), key="q2_quarters"
        )
        window = q2_from if q2_from == q2_to else f"{q2_from}–{q2_to}"
        q2 = query(Q2, reference_date=stichtag, planned_end_from=q2_from, planned_end_to=q2_to)
        stacked(q2, "funding_type" if q2.training_id.nunique() == 1 else "training_id",
                title=f"Anteil, geplantes Ende {window}")  # fmt: skip
        with st.expander("Tabelle"):
            table(q2, "geplantes Ende", window)
    q4 = query(Q4, reference_date=stichtag)
    with block(Q4, "NPS gesamt: alle Antworten des Abschlussfeedbacks, Absolventen und Abbrecher; "
                   f"Zellen mit n < {MIN_N} blass",
               f"Abgabedatum, je Quartal der Abgabe; Antworten bis zum Ende des {STAND}"):  # fmt: skip
        quarters = sorted(q4.quarter.unique())
        if not set(st.session_state.get("q4_quarters", ())) <= set(quarters):
            st.session_state.pop("q4_quarters", None)  # a Stichtag change removed a quarter
        start, end = st.select_slider(
            "Quartale der Abgabe", quarters, (quarters[0], quarters[-1]), key="q4_quarters"
        )
        shown = q4[(q4.quarter >= start) & (q4.quarter <= end)]
        largest = max(int(q4.n.max()), 2)
        if not set(st.session_state.get("q4_n", ())) <= set(range(1, largest + 1)):
            st.session_state.pop("q4_n", None)  # a Stichtag change shrank the largest cell
        low, high = st.slider("Antworten je Zelle", 1, largest, (1, largest), key="q4_n")
        shown = shown[shown.n.between(low, high)]
        heatmap(shown)
        with st.expander("Tabelle"):
            table(shown.rename(columns={"quarter": "Abgabequartal"})[
                ["Abgabequartal", *shown.columns.drop("quarter")]])  # fmt: skip

    # The five numbers; aktiv and im Verzug against the previous week's reading.
    q3_before = query(Q3, reference_date=VORWOCHE, behind_schedule_pp=pp)
    with cards:
        for col, draw in zip(st.columns(5), range(5)):
            with col:
                if draw == 0:
                    card("(Q1) aktiv", int(q1.active.sum()),
                         int(query(Q1, reference_date=VORWOCHE).active.sum()))  # fmt: skip
                elif draw == 1:
                    card(f"(Q2) Abschlussquote · n {q2.n.sum()}", share(q2, "completed", "n"),
                         unit=" %", help=f"geplantes Ende {window}")  # fmt: skip
                elif draw == 2:
                    card(f"(Q3) im Verzug ab {pp} pp · {q3.behind_schedule.sum()}/{q3.n.sum()}",
                         share(q3, "behind_schedule", "n"),
                         share(q3_before, "behind_schedule", "n"), inverse=True, unit=" %",
                         delta_unit=" pp")  # fmt: skip
                elif draw == 3:
                    card(f"(Q4) NPS gesamt · n {shown.n.sum()}", nps(shown),
                         help=f"Abgabe {start}–{end}")  # fmt: skip
                else:
                    q5_before = query(Q5, reference_date=VORWOCHE)
                    card(f"(Q5) ohne Coach · von {q5.enrollments.sum()}", ohne_coach(q5),
                         ohne_coach(q5_before), inverse=True,
                         help="alle Trainings; die Auswahl Training/Variante gilt hier nicht"
                         if FILTERED else None)  # fmt: skip
    footer(pp)


def handlungsbedarf():
    with block(WORKLISTS / "im_verzug.sql",
               "aktive Teilnahmen hinter dem Zeitplan, der größte Rückstand zuerst",
               f"aktiv am Ende des {STAND}"):  # fmt: skip
        pp = schwelle("pp_worklist")
        worklist("im_verzug", reference_date=stichtag, behind_schedule_pp=pp)
    with block(WORKLISTS / "ohne_coach.sql", "aktive oder pausierte Teilnahmen ohne Coach",
               f"Status am Ende des {STAND}"):  # fmt: skip
        worklist("ohne_coach", reference_date=stichtag)
    with block(WORKLISTS / "betreuungsliste_bereinigen.sql",
               "Zeilen der Betreuungsliste mit einem Hinweis",
               f"Betreuungsliste, Datenstand {data_as_of()}; der Stichtag gilt hier nicht, "
               "Training und Variante schon"):  # fmt: skip
        worklist("betreuungsliste_bereinigen", date_label="Datenstand", date_value=data_as_of())
    footer(pp)


def worklist(name: str, date_label="Stand am", date_value=None, **params):
    """One Handlungsbedarf list: hints spelled out and counted, the table, a CSV download."""
    df = query(WORKLISTS / f"{name}.sql", **params)
    if "data_quality_issues" in df:
        counts = df.data_quality_issues.explode().map(HINTS).value_counts()
        st.caption(" · ".join(f"{hint} {count}" for hint, count in counts.items()))
        df["data_quality_issues"] = df.data_quality_issues.map(
            lambda codes: " · ".join(HINTS[code] for code in codes)
        )
    st.markdown(f"**{len(df)} Zeilen**")
    table(df, date_label, date_value or STAND)
    df.insert(0, date_label, date_value or STAND)
    st.download_button("CSV herunterladen", df.to_csv(index=False), f"{name}.csv", key=name)


st.navigation(
    [
        st.Page(ueberblick, title="Überblick", url_path="ueberblick", default=True),
        st.Page(handlungsbedarf, title="🚨 Handlungsbedarf", url_path="handlungsbedarf"),
    ],
    position="top",
).run()
