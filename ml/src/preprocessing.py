"""
Preprocessing utilities for Finance Tracker ML pipeline.
Handles category mapping, text cleaning, and feature engineering.
"""

import re
import numpy as np
import pandas as pd

# ──────────────────────────────────────────────
# Category mapping: source dataset → our 12 app categories
# ──────────────────────────────────────────────
CATEGORY_MAP = {
    # personal_transactions.csv categories → app categories
    'Groceries': 'groceries',
    'Restaurants': 'dining',
    'Fast Food': 'dining',
    'Coffee Shops': 'dining',
    'Alcohol & Bars': 'dining',
    'Gas & Fuel': 'transport',
    'Auto Insurance': 'transport',
    'Utilities': 'utilities',
    'Internet': 'utilities',
    'Mobile Phone': 'utilities',
    'Television': 'utilities',
    'Entertainment': 'entertainment',
    'Movies & DVDs': 'entertainment',
    'Music': 'entertainment',
    'Haircut': 'healthcare',
    'Shopping': 'shopping',
    'Electronics & Software': 'shopping',
    'Home Improvement': 'shopping',
    'Mortgage & Rent': 'rent',
    'Paycheck': 'salary',
    'Credit Card Payment': 'transfer',
}

APP_CATEGORIES = [
    'groceries', 'dining', 'transport', 'utilities', 'entertainment',
    'healthcare', 'shopping', 'rent', 'salary', 'freelance',
    'transfer', 'other',
]

CATEGORY_TO_IDX = {cat: idx for idx, cat in enumerate(APP_CATEGORIES)}
IDX_TO_CATEGORY = {idx: cat for cat, idx in CATEGORY_TO_IDX.items()}


def map_category(original_category: str) -> str:
    """Map a source dataset category to one of our 12 app categories."""
    return CATEGORY_MAP.get(original_category, 'other')


def clean_merchant_text(text: str) -> str:
    """Clean and normalize merchant/description text for tokenization."""
    if not isinstance(text, str):
        return ''
    text = text.lower().strip()
    # Remove special characters, keep alphanumeric and spaces
    text = re.sub(r'[^a-z0-9\s]', ' ', text)
    # Collapse whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def load_personal_transactions(filepath: str) -> pd.DataFrame:
    """Load and normalize personal_transactions.csv."""
    df = pd.read_csv(filepath)
    df.columns = df.columns.str.strip()

    df['date'] = pd.to_datetime(df['Date'], format='%m/%d/%Y')
    df['merchant'] = df['Description'].astype(str)
    df['merchant_clean'] = df['merchant'].apply(clean_merchant_text)
    df['amount'] = df['Amount'].astype(float).abs()
    df['original_category'] = df['Category'].astype(str)
    df['category'] = df['original_category'].map(map_category)
    df['type'] = df['Transaction Type'].map(
        {'debit': 'expense', 'credit': 'income'}
    ).fillna('expense')
    df['category_idx'] = df['category'].map(CATEGORY_TO_IDX)

    return df[['date', 'merchant', 'merchant_clean', 'amount',
               'original_category', 'category', 'category_idx', 'type']]


def load_creditcard(filepath: str) -> pd.DataFrame:
    """Load creditcard.csv for anomaly detection."""
    df = pd.read_csv(filepath)
    df['is_fraud'] = df['Class'].astype(int)
    df['amount'] = df['Amount'].astype(float)
    feature_cols = [f'V{i}' for i in range(1, 29)]
    return df[feature_cols + ['amount', 'is_fraud']]


def load_synthetic_finance(filepath: str) -> pd.DataFrame:
    """Load synthetic_personal_finance_dataset.csv for savings recommendations."""
    df = pd.read_csv(filepath)
    df['record_date'] = pd.to_datetime(df['record_date'])
    return df


def load_budget(filepath: str) -> pd.DataFrame:
    """Load Budget.csv and map to app categories."""
    df = pd.read_csv(filepath)
    df.columns = df.columns.str.strip()
    df['app_category'] = df['Category'].map(map_category)
    return df
