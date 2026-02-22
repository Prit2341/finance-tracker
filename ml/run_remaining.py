"""Run notebooks 04 (forecast) and 05 (savings) with LSTM TFLite export fix."""
import sys, os, json, warnings
warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
os.chdir(os.path.join(os.path.dirname(__file__), 'notebooks'))

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.metrics import accuracy_score
from evaluate import print_regression_metrics

print(f'TF {tf.__version__}')

# ============================================================
# NOTEBOOK 04: SPENDING FORECAST (with LSTM TFLite fix)
# ============================================================
print('\n' + '='*60)
print('NOTEBOOK 04: SPENDING FORECAST')
print('='*60)

from data_generator import generate_synthetic_transactions

# Generate sufficient time series data
synth_txns = generate_synthetic_transactions(n=5000, start_date='2022-01-01', end_date='2024-12-31', seed=42)
synth_daily = synth_txns[synth_txns['type'] == 'expense']
synth_daily = synth_daily.copy()
synth_daily['date'] = pd.to_datetime(synth_daily['date'])
daily_totals = synth_daily.groupby('date')['amount'].sum().reset_index()
daily_totals.columns = ['date', 'daily_total']
dr = pd.date_range(daily_totals['date'].min(), daily_totals['date'].max())
daily_totals = daily_totals.set_index('date').reindex(dr, fill_value=0).reset_index()
daily_totals.columns = ['date', 'daily_total']
values = daily_totals['daily_total'].values.astype(np.float32)
print(f'Daily spending: {len(values)} days')

scaler_fc = MinMaxScaler()
values_scaled = scaler_fc.fit_transform(values.reshape(-1, 1)).flatten()

LOOKBACK = 30
HORIZON = 7

X_fc, y_fc = [], []
for i in range(len(values_scaled) - LOOKBACK - HORIZON + 1):
    X_fc.append(values_scaled[i:i + LOOKBACK])
    y_fc.append(values_scaled[i + LOOKBACK:i + LOOKBACK + HORIZON])
X_fc = np.array(X_fc).reshape(-1, LOOKBACK, 1).astype(np.float32)
y_fc = np.array(y_fc).astype(np.float32)
print(f'Windows: {X_fc.shape[0]}')

split_idx = int(len(X_fc) * 0.8)
X_train_fc, X_test_fc = X_fc[:split_idx], X_fc[split_idx:]
y_train_fc, y_test_fc = y_fc[:split_idx], y_fc[split_idx:]
print(f'Train: {len(X_train_fc)}, Test: {len(X_test_fc)}')

# Use unroll=True to avoid TensorList ops that fail in TFLite
fc_model = tf.keras.Sequential([
    tf.keras.layers.LSTM(32, input_shape=(LOOKBACK, 1), unroll=True),
    tf.keras.layers.Dense(16, activation='relu'),
    tf.keras.layers.Dense(HORIZON),
])
fc_model.compile(optimizer='adam', loss='mse', metrics=['mae'])

print('Training forecaster (unrolled LSTM)...')
history_fc = fc_model.fit(
    X_train_fc, y_train_fc,
    validation_split=0.15, epochs=50, batch_size=32,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True, monitor='val_loss'),
    ],
    verbose=1,
)

y_pred_fc = fc_model.predict(X_test_fc, verbose=0)
y_test_real = scaler_fc.inverse_transform(y_test_fc.reshape(-1, 1)).reshape(y_test_fc.shape)
y_pred_real = scaler_fc.inverse_transform(y_pred_fc.reshape(-1, 1)).reshape(y_pred_fc.shape)
print('\nForecast Metrics:')
fc_metrics = print_regression_metrics(y_test_real.flatten(), y_pred_real.flatten())

# Export with SELECT_TF_OPS fallback
fc_model.save('../models/saved/forecast_keras.keras')

converter = tf.lite.TFLiteConverter.from_keras_model(fc_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS,
]
converter._experimental_lower_tensor_list_ops = False
tflite_model = converter.convert()
with open('../models/tflite/forecast.tflite', 'wb') as f:
    f.write(tflite_model)
print(f'Forecast TFLite: {len(tflite_model)/1024:.1f} KB')

forecast_config = {
    'lookback': LOOKBACK, 'horizon': HORIZON,
    'scaler': {'min': float(scaler_fc.data_min_[0]), 'max': float(scaler_fc.data_max_[0])},
    'metrics': {'mae': float(fc_metrics['mae']), 'rmse': float(fc_metrics['rmse']), 'mape': float(fc_metrics['mape'])},
}
with open('../models/tflite/forecast_config.json', 'w') as f:
    json.dump(forecast_config, f, indent=2)

print('\n[OK] Forecaster trained and exported!')

# ============================================================
# NOTEBOOK 05: SAVINGS RECOMMENDATIONS
# ============================================================
print('\n' + '='*60)
print('NOTEBOOK 05: SAVINGS RECOMMENDATIONS')
print('='*60)

from preprocessing import APP_CATEGORIES

df_sav = pd.read_csv('../data/processed/savings_train.csv')
print(f'Savings dataset: {len(df_sav)} rows')

features_sav = pd.DataFrame()
features_sav['expense_ratio'] = df_sav['expense_ratio']
features_sav['savings_rate'] = df_sav['savings_rate']
features_sav['discretionary_ratio'] = features_sav['expense_ratio'] * 0.4
features_sav['essential_ratio'] = features_sav['expense_ratio'] * 0.6
features_sav['credit_util'] = df_sav['debt_to_income_ratio'].clip(upper=1.0)

def label_risk(row):
    if row['savings_rate'] > 0.20: return 0
    elif row['savings_rate'] > 0.05: return 1
    else: return 2

labels_sav = features_sav.apply(label_risk, axis=1).values
RISK_LABELS = ['healthy', 'moderate', 'at_risk']
for i, label in enumerate(RISK_LABELS):
    print(f'  {label}: {(labels_sav == i).sum()} ({(labels_sav == i).mean():.1%})')

X_sav = features_sav.values.astype(np.float32)
X_train_sav, X_test_sav, y_train_sav, y_test_sav = train_test_split(
    X_sav, labels_sav, test_size=0.2, random_state=42, stratify=labels_sav
)
scaler_sav = StandardScaler()
X_train_sav_s = scaler_sav.fit_transform(X_train_sav)
X_test_sav_s = scaler_sav.transform(X_test_sav)

keras_sav = tf.keras.Sequential([
    tf.keras.layers.Dense(16, activation='relu', input_shape=(5,)),
    tf.keras.layers.Dense(8, activation='relu'),
    tf.keras.layers.Dense(3, activation='softmax'),
])
keras_sav.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

print('Training savings advisor...')
keras_sav.fit(
    X_train_sav_s, y_train_sav,
    validation_split=0.15, epochs=50, batch_size=32,
    callbacks=[tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True, monitor='val_accuracy')],
    verbose=1,
)

y_pred_sav = np.argmax(keras_sav.predict(X_test_sav_s, verbose=0), axis=1)
sav_acc = accuracy_score(y_test_sav, y_pred_sav)
print(f'Savings accuracy: {sav_acc:.4f}')

keras_sav.save('../models/saved/savings_advisor_keras.keras')
converter_sav = tf.lite.TFLiteConverter.from_keras_model(keras_sav)
converter_sav.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_sav = converter_sav.convert()
with open('../models/tflite/savings_advisor.tflite', 'wb') as f:
    f.write(tflite_sav)
print(f'Savings TFLite: {len(tflite_sav)/1024:.1f} KB')

savings_config = {
    'input_dim': 5, 'num_classes': 3,
    'risk_labels': RISK_LABELS,
    'feature_names': list(features_sav.columns),
    'scaler': {'mean': scaler_sav.mean_.tolist(), 'std': scaler_sav.scale_.tolist()},
    'metrics': {'accuracy': float(sav_acc)},
}
with open('../models/tflite/savings_config.json', 'w') as f:
    json.dump(savings_config, f, indent=2)

recommendations = {
    "risk_levels": {
        "healthy": {"title": "Great Financial Health", "description": "You're saving well! Here are ways to optimize further.", "icon": "emoji_events"},
        "moderate": {"title": "Room for Improvement", "description": "Your spending is manageable, but you could save more.", "icon": "trending_up"},
        "at_risk": {"title": "Action Needed", "description": "Your expenses are close to or exceeding your income.", "icon": "warning"},
    },
    "rules": [
        {"id": "high_dining", "title": "Reduce Dining Expenses", "description": "Dining makes up {ratio}% of your spending. Try meal prepping to cut costs by 30-50%.", "category": "dining", "threshold": 0.15, "priority": "high", "potential_savings": 0.3},
        {"id": "high_entertainment", "title": "Optimize Entertainment Budget", "description": "Entertainment is {ratio}% of spending. Consider free alternatives or shared subscriptions.", "category": "entertainment", "threshold": 0.10, "priority": "medium", "potential_savings": 0.25},
        {"id": "high_shopping", "title": "Curb Shopping Spending", "description": "Shopping is {ratio}% of your expenses. Try a 24-hour rule before non-essential purchases.", "category": "shopping", "threshold": 0.20, "priority": "high", "potential_savings": 0.35},
        {"id": "high_transport", "title": "Lower Transport Costs", "description": "Transport is {ratio}% of spending. Consider carpooling, public transit, or biking.", "category": "transport", "threshold": 0.15, "priority": "medium", "potential_savings": 0.20},
        {"id": "high_groceries", "title": "Optimize Grocery Budget", "description": "Groceries are {ratio}% of spending. Plan meals, buy in bulk, and use coupons.", "category": "groceries", "threshold": 0.25, "priority": "medium", "potential_savings": 0.15},
        {"id": "no_savings", "title": "Start an Emergency Fund", "description": "You're saving less than 5%. Aim to save at least 10% of income as a safety net.", "category": null, "threshold": 0.05, "priority": "critical", "potential_savings": null},
        {"id": "spending_increase", "title": "Spending Increased Significantly", "description": "Your spending increased {increase}% from last month. Review recent purchases for non-essentials.", "category": null, "threshold": 0.20, "priority": "high", "potential_savings": null},
        {"id": "high_utilities", "title": "Reduce Utility Bills", "description": "Utilities are {ratio}% of spending. Check for better plans, reduce usage, or switch providers.", "category": "utilities", "threshold": 0.12, "priority": "low", "potential_savings": 0.10},
    ]
}
with open('../models/tflite/recommendation_templates.json', 'w') as f:
    json.dump(recommendations, f, indent=2)

print('\n[OK] Savings advisor trained and exported!')

# Summary
print('\n' + '='*60)
print('ALL REMAINING MODELS EXPORTED')
print('='*60)
tflite_dir = '../models/tflite'
for f in sorted(os.listdir(tflite_dir)):
    size = os.path.getsize(os.path.join(tflite_dir, f))
    print(f'  {f:45s} {size/1024:>8.1f} KB')
