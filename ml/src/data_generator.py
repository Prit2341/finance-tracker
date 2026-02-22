"""
Synthetic data augmentation for Finance Tracker ML pipeline.
Supplements real Kaggle data with additional merchants and categories.
"""

import random
import uuid
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

from preprocessing import (
    APP_CATEGORIES, CATEGORY_TO_IDX, clean_merchant_text
)

# Merchant pools per category for synthetic augmentation
MERCHANT_POOLS = {
    'groceries': [
        'Walmart', 'Kroger', 'Whole Foods', 'Aldi', 'Trader Joes',
        'Costco', 'Safeway', 'Publix', 'HEB', 'Wegmans',
        'Target Grocery', 'Lidl', 'Food Lion', 'Meijer', 'Sprouts',
    ],
    'dining': [
        'McDonalds', 'Starbucks', 'Chipotle', 'Pizza Hut', 'Subway',
        'Panera Bread', 'Chick Fil A', 'Taco Bell', 'Wendys', 'Dunkin',
        'Olive Garden', 'Applebees', 'Buffalo Wild Wings', 'IHOP',
        'Thai Restaurant', 'Sushi Bar', 'Italian Bistro', 'Diner',
        'Coffee Shop', 'Burger King', 'Dominos', 'Papa Johns',
    ],
    'transport': [
        'Shell Gas', 'Uber', 'Lyft', 'BP Fuel', 'Chevron',
        'ExxonMobil', 'Amtrak', 'Delta Airlines', 'United Airlines',
        'Enterprise Rental', 'Hertz', 'Parking Meter', 'Toll Road',
        'Auto Repair Shop', 'Jiffy Lube', 'State Farm Insurance',
    ],
    'utilities': [
        'Electric Company', 'Water Department', 'Comcast', 'Verizon',
        'ATT Wireless', 'T-Mobile', 'Gas Company', 'City Water',
        'Power Company', 'Internet Provider', 'Spectrum', 'Cox',
    ],
    'entertainment': [
        'Netflix', 'Spotify', 'AMC Theatres', 'Regal Cinemas',
        'Disney Plus', 'Hulu', 'HBO Max', 'Apple Music',
        'Steam Games', 'PlayStation Store', 'Xbox Store', 'Audible',
        'YouTube Premium', 'Concert Venue', 'Bowling Alley',
    ],
    'healthcare': [
        'CVS Pharmacy', 'Walgreens', 'Urgent Care', 'Dentist Office',
        'Eye Doctor', 'Hospital', 'Lab Corp', 'Physical Therapy',
        'Dermatologist', 'Hair Salon', 'Barbershop', 'Gym Membership',
    ],
    'shopping': [
        'Amazon', 'Target', 'Best Buy', 'Home Depot', 'Lowes',
        'Walmart Online', 'Macys', 'Nordstrom', 'TJ Maxx', 'Ross',
        'IKEA', 'Bed Bath Beyond', 'Wayfair', 'Etsy', 'eBay',
        'Nike', 'Apple Store', 'Hardware Store',
    ],
    'rent': [
        'Mortgage Payment', 'Rent Payment', 'Property Management',
        'Apartment Rent', 'HOA Fees', 'Landlord Payment',
    ],
    'salary': [
        'Biweekly Paycheck', 'Monthly Salary', 'Direct Deposit',
        'Payroll', 'Employer Payment', 'Salary Deposit',
    ],
    'freelance': [
        'Freelance Payment', 'Client Payment', 'Upwork', 'Fiverr',
        'Consulting Fee', 'Side Gig Income', 'Contract Work',
    ],
    'transfer': [
        'Credit Card Payment', 'Bank Transfer', 'Venmo', 'Zelle',
        'PayPal Transfer', 'Wire Transfer', 'ACH Transfer',
    ],
    'other': [
        'Miscellaneous', 'Cash Withdrawal', 'ATM Withdrawal',
        'Unknown Merchant', 'Pending Transaction', 'Refund',
    ],
}

# Amount ranges (min, max) per category
AMOUNT_RANGES = {
    'groceries': (15, 250),
    'dining': (5, 100),
    'transport': (10, 200),
    'utilities': (30, 300),
    'entertainment': (5, 80),
    'healthcare': (15, 500),
    'shopping': (10, 500),
    'rent': (800, 2500),
    'salary': (1500, 8000),
    'freelance': (200, 5000),
    'transfer': (50, 3000),
    'other': (5, 200),
}

# Category weights for realistic distribution
CATEGORY_WEIGHTS = {
    'groceries': 0.15,
    'dining': 0.18,
    'transport': 0.10,
    'utilities': 0.08,
    'entertainment': 0.08,
    'healthcare': 0.04,
    'shopping': 0.12,
    'rent': 0.03,
    'salary': 0.05,
    'freelance': 0.02,
    'transfer': 0.08,
    'other': 0.07,
}


def generate_synthetic_transactions(
    n: int = 5000,
    start_date: str = '2022-01-01',
    end_date: str = '2024-12-31',
    anomaly_ratio: float = 0.02,
    seed: int = 42,
) -> pd.DataFrame:
    """Generate synthetic transaction data for augmentation."""
    random.seed(seed)
    np.random.seed(seed)

    categories = list(CATEGORY_WEIGHTS.keys())
    weights = list(CATEGORY_WEIGHTS.values())

    start = datetime.strptime(start_date, '%Y-%m-%d')
    end = datetime.strptime(end_date, '%Y-%m-%d')
    date_range = (end - start).days

    records = []
    for _ in range(n):
        cat = random.choices(categories, weights=weights, k=1)[0]
        merchant = random.choice(MERCHANT_POOLS[cat])
        lo, hi = AMOUNT_RANGES[cat]
        amount = round(random.uniform(lo, hi), 2)
        txn_type = 'income' if cat in ('salary', 'freelance') else 'expense'
        date = start + timedelta(days=random.randint(0, date_range))

        records.append({
            'id': str(uuid.uuid4()),
            'date': date,
            'merchant': merchant,
            'merchant_clean': clean_merchant_text(merchant),
            'amount': amount,
            'category': cat,
            'category_idx': CATEGORY_TO_IDX[cat],
            'type': txn_type,
            'is_anomaly': 0,
            'source': 'synthetic',
        })

    df = pd.DataFrame(records)

    # Inject anomalies: unusually large amounts
    n_anomalies = int(len(df) * anomaly_ratio)
    anomaly_indices = df.sample(n=n_anomalies, random_state=seed).index
    df.loc[anomaly_indices, 'amount'] *= np.random.uniform(3, 10, size=n_anomalies)
    df.loc[anomaly_indices, 'amount'] = df.loc[anomaly_indices, 'amount'].round(2)
    df.loc[anomaly_indices, 'is_anomaly'] = 1

    return df


def augment_dataset(
    real_df: pd.DataFrame,
    target_per_category: int = 500,
    seed: int = 42,
) -> pd.DataFrame:
    """
    Augment real data with synthetic transactions to balance categories.
    Generates extra synthetic rows for underrepresented categories.
    """
    random.seed(seed)
    np.random.seed(seed)

    category_counts = real_df['category'].value_counts()
    augmented_rows = []

    for cat in APP_CATEGORIES:
        current_count = category_counts.get(cat, 0)
        needed = max(0, target_per_category - current_count)

        if needed > 0:
            merchants = MERCHANT_POOLS.get(cat, ['Unknown'])
            lo, hi = AMOUNT_RANGES.get(cat, (5, 100))
            txn_type = 'income' if cat in ('salary', 'freelance') else 'expense'

            for _ in range(needed):
                merchant = random.choice(merchants)
                amount = round(random.uniform(lo, hi), 2)
                date = datetime(2023, 1, 1) + timedelta(
                    days=random.randint(0, 730)
                )

                augmented_rows.append({
                    'date': date,
                    'merchant': merchant,
                    'merchant_clean': clean_merchant_text(merchant),
                    'amount': amount,
                    'category': cat,
                    'category_idx': CATEGORY_TO_IDX[cat],
                    'type': txn_type,
                    'is_anomaly': 0,
                    'source': 'augmented',
                })

    if augmented_rows:
        aug_df = pd.DataFrame(augmented_rows)
        combined = pd.concat([real_df, aug_df], ignore_index=True)
    else:
        combined = real_df.copy()

    return combined


if __name__ == '__main__':
    # Quick test
    df = generate_synthetic_transactions(n=100)
    print(f'Generated {len(df)} transactions')
    print(f'Categories: {df["category"].value_counts().to_dict()}')
    print(f'Anomalies: {df["is_anomaly"].sum()}')
    print(df.head())
