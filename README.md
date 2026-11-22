# Data Analyst Portfolio

Data analysis projects using **SQL, Python (pandas), and data visualisation**.
Each project folder has its own README with the business problem, steps, findings and charts.

## Projects

| Project | Skills | Summary |
|---|---|---|
| [Superstore Sales Analysis](sales-analysis/) | SQL (CTEs, window functions, joins), pandas, matplotlib, seaborn, Jupyter | Cleaned 10K retail order lines, wrote 14 SQL queries, and showed that discounts above 20% wiped out $135K of profit. The loss-making products are profitable at full price. |

## Setup

Requires Python 3.10 or newer.

```bash
# 1. (optional) create a virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS / Linux

# 2. install the libraries
pip install -r requirements.txt

# 3. open a project notebook
cd sales-analysis
jupyter notebook
```

SQLite is built into Python (`import sqlite3`), so there is no database server to install.
