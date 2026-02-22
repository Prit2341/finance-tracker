"""
Run all ML pipeline notebooks (00-05) as a single script.
Trains all models and exports TFLite + config files.
"""
import sys
import os
import json
import warnings
warnings.filterwarnings('ignore')

# Ensure src is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
os.chdir(os.path.join(os.path.dirname(__file__), 'notebooks'))

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import IsolationForest
from sklearn.metrics import (
    precision_score, recall_score, f1_score, roc_auc_score, accuracy_score
)
from sklearn.utils.class_weight import compute_class_weight
from sklearn.tree import DecisionTreeClassifier

from preprocessing import (
    load_personal_transactions, load_creditcard, load_synthetic_finance,
    load_budget, CATEGORY_MAP, APP_CATEGORIES, CATEGORY_TO_IDX, IDX_TO_CATEGORY,
    clean_merchant_text, map_category
)
from data_generator import augment_dataset, generate_synthetic_transactions
from export_tflite import (
    export_keras_to_tflite, export_tokenizer,
    export_category_labels, verify_tflite_model
)
from evaluate import print_classification_metrics, print_regression_metrics

print(f'TensorFlow version: {tf.__version__}')
print('='*60)

# ============================================================
# NOTEBOOK 01: DATA PREPROCESSING
# ============================================================
print('\n' + '='*60)
print('NOTEBOOK 01: DATA PREPROCESSING')
print('='*60)

# Process personal transactions
personal = load_personal_transactions('../../dataset/personal_transactions.csv')
print(f'Loaded {len(personal)} personal transactions')

personal['source'] = 'real'
personal['is_anomaly'] = 0

# Augment to balance categories
combined = augment_dataset(personal, target_per_category=200, seed=42)
print(f'After augmentation: {len(combined)} rows')
print(f'Category distribution:\n{combined["category"].value_counts().sort_index()}')

# Save categorization dataset
categorization_df = combined[['merchant_clean', 'category', 'category_idx']].copy()
categorization_df = categorization_df[categorization_df['merchant_clean'].str.len() > 0]
categorization_df.to_csv('../data/processed/categorization_train.csv', index=False)
print(f'\nCategorization dataset: {len(categorization_df)} rows saved')

# Process credit card data for anomaly detection
creditcard = load_creditcard('../../dataset/creditcard.csv')
print(f'Credit card dataset: {len(creditcard)} rows, fraud: {creditcard["is_fraud"].sum()}')
creditcard.to_csv('../data/processed/anomaly_train.csv', index=False)

# Process synthetic finance for savings
synthetic = load_synthetic_finance('../../dataset/synthetic_personal_finance_dataset.csv')
synthetic['expense_ratio'] = synthetic['monthly_expenses_usd'] / synthetic['monthly_income_usd']
synthetic['savings_rate'] = 1 - synthetic['expense_ratio']
synthetic['has_high_debt'] = (synthetic['debt_to_income_ratio'] > 0.4).astype(int)
savings_df = synthetic[[
    'monthly_income_usd', 'monthly_expenses_usd', 'savings_usd',
    'credit_score', 'debt_to_income_ratio', 'expense_ratio',
    'savings_rate', 'has_high_debt', 'has_loan', 'employment_status'
]].copy()
savings_df.to_csv('../data/processed/savings_train.csv', index=False)
print(f'Savings dataset: {len(savings_df)} rows saved')

# Time series for forecast
ts_data = combined[combined['type'] == 'expense'][['date', 'amount']].copy()
ts_data['date'] = pd.to_datetime(ts_data['date'])
daily_totals = ts_data.groupby('date')['amount'].sum().reset_index()
daily_totals.columns = ['date', 'daily_total']
date_range = pd.date_range(daily_totals['date'].min(), daily_totals['date'].max())
daily_totals = daily_totals.set_index('date').reindex(date_range, fill_value=0).reset_index()
daily_totals.columns = ['date', 'daily_total']
daily_totals.to_csv('../data/processed/daily_spending.csv', index=False)
print(f'Daily spending: {len(daily_totals)} days saved')

# Budget reference
budget = load_budget('../../dataset/Budget.csv')
app_budget = budget.groupby('app_category')['Budget'].sum().reset_index()
app_budget.columns = ['category', 'monthly_budget']
for cat in APP_CATEGORIES:
    if cat not in app_budget['category'].values:
        app_budget = pd.concat([
            app_budget, pd.DataFrame({'category': [cat], 'monthly_budget': [0]})
        ], ignore_index=True)
app_budget.to_csv('../data/processed/budget_reference.csv', index=False)
print('Budget reference saved')

print('\n[OK] Preprocessing complete!')

# ============================================================
# NOTEBOOK 02: AUTO-CATEGORIZATION
# ============================================================
print('\n' + '='*60)
print('NOTEBOOK 02: AUTO-CATEGORIZATION')
print('='*60)

df = pd.read_csv('../data/processed/categorization_train.csv')
texts = df['merchant_clean'].values
labels = df['category_idx'].values

VOCAB_SIZE = 2000
MAX_LEN = 10
EMBEDDING_DIM = 32
LSTM_UNITS = 32
NUM_CLASSES = len(APP_CATEGORIES)

tokenizer = tf.keras.preprocessing.text.Tokenizer(
    num_words=VOCAB_SIZE, oov_token='<OOV>'
)
tokenizer.fit_on_texts(texts)
sequences = tokenizer.texts_to_sequences(texts)
padded = tf.keras.preprocessing.sequence.pad_sequences(
    sequences, maxlen=MAX_LEN, padding='post', truncating='post'
)
print(f'Vocabulary: {len(tokenizer.word_index)} tokens, using top {VOCAB_SIZE}')
print(f'Padded shape: {padded.shape}')

X_train, X_test, y_train, y_test = train_test_split(
    padded, labels, test_size=0.2, random_state=42, stratify=labels
)
print(f'Train: {X_train.shape[0]}, Test: {X_test.shape[0]}')

class_weights_arr = compute_class_weight('balanced', classes=np.unique(y_train), y=y_train)
class_weights = dict(enumerate(class_weights_arr))

model = tf.keras.Sequential([
    tf.keras.layers.Embedding(VOCAB_SIZE, EMBEDDING_DIM, input_length=MAX_LEN),
    tf.keras.layers.LSTM(LSTM_UNITS),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(NUM_CLASSES, activation='softmax'),
])
model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

print('Training categorizer...')
history = model.fit(
    X_train, y_train,
    validation_split=0.15, epochs=30, batch_size=32,
    class_weight=class_weights,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True, monitor='val_accuracy'),
        tf.keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3, monitor='val_loss'),
    ],
    verbose=1,
)

y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
cat_metrics = print_classification_metrics(y_test, y_pred, label_names=APP_CATEGORIES)

# Export
model.save('../models/saved/categorizer_keras.keras')
tflite_meta = export_keras_to_tflite(model, '../models/tflite/categorizer.tflite', quantize=True)
export_tokenizer(tokenizer.word_index, '../models/tflite/tokenizer.json')
export_category_labels(APP_CATEGORIES, '../models/tflite/categories.json')

config = {
    'vocab_size': VOCAB_SIZE, 'max_len': MAX_LEN, 'num_classes': NUM_CLASSES,
    'categories': APP_CATEGORIES, 'confidence_threshold': 0.8,
    'metrics': {'accuracy': float(cat_metrics['accuracy']), 'f1_weighted': float(cat_metrics['f1_weighted'])},
}
with open('../models/tflite/categorizer_config.json', 'w') as f:
    json.dump(config, f, indent=2)

# Verify (use batch of 1 via resize_tensor_input)
def verify_tflite_single(tflite_path, sample_input):
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    # Resize to single sample
    new_shape = list(input_details[0]['shape'])
    new_shape[0] = 1
    interpreter.resize_tensor_input(input_details[0]['index'], new_shape)
    interpreter.allocate_tensors()
    interpreter.set_tensor(input_details[0]['index'], sample_input[:1])
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    print(f'TFLite verify: input={new_shape}, output={output[0][:5]}...')
    return output

verify_tflite_single('../models/tflite/categorizer.tflite', X_test[:1].astype(np.float32))

# Quick test on real merchant names
test_merchants = ['Starbucks', 'Walmart', 'Uber', 'Netflix', 'Shell Gas', 'Amazon', 'CVS Pharmacy']
cleaned = [clean_merchant_text(m) for m in test_merchants]
seqs = tokenizer.texts_to_sequences(cleaned)
padded_test = tf.keras.preprocessing.sequence.pad_sequences(seqs, maxlen=MAX_LEN, padding='post', truncating='post')
probs = model.predict(padded_test, verbose=0)
print(f'\n{"Merchant":25s} {"Predicted":15s} {"Confidence":>10s}')
print('-' * 55)
for i, merchant in enumerate(test_merchants):
    top_idx = np.argmax(probs[i])
    print(f'{merchant:25s} {IDX_TO_CATEGORY[top_idx]:15s} {probs[i][top_idx]:>9.1%}')

print('\n[OK] Categorizer trained and exported!')

# ============================================================
# NOTEBOOK 03: ANOMALY DETECTION
# ============================================================
print('\n' + '='*60)
print('NOTEBOOK 03: ANOMALY DETECTION')
print('='*60)

df_anom = pd.read_csv('../data/processed/anomaly_train.csv')
print(f'Dataset: {len(df_anom)} rows, anomalies: {df_anom["is_anomaly"].sum() if "is_anomaly" in df_anom.columns else df_anom["is_fraud"].sum()}')

# The credit card dataset uses V1-V28 features + amount
# We'll build features that match what Flutter can compute
# For credit card data: use V1-V28 + amount directly (already PCA-transformed)
if 'is_fraud' in df_anom.columns:
    feature_cols = [c for c in df_anom.columns if c.startswith('V') or c == 'amount']
    X_all = df_anom[feature_cols].values.astype(np.float32)
    is_anomaly = df_anom['is_fraud'].values.astype(bool)
else:
    is_anomaly = df_anom['is_anomaly'].values.astype(bool)
    X_all = df_anom.drop(columns=['is_anomaly']).values.astype(np.float32)

# However, for our Flutter app we need features based on transaction attributes,
# not PCA features from credit card data. Let's generate app-style features
# from our combined transaction data instead.
print('Building app-compatible anomaly features from transaction data...')

# Generate more synthetic data with anomalies for training
synth_txns = generate_synthetic_transactions(n=10000, anomaly_ratio=0.02, seed=42)

def build_app_features(df):
    features = pd.DataFrame()
    features['log_amount'] = np.log1p(df['amount'].astype(float))
    for cat in APP_CATEGORIES:
        features[f'cat_{cat}'] = (df['category'] == cat).astype(float)
    dates = pd.to_datetime(df['date'])
    dow = dates.dt.dayofweek
    features['dow_sin'] = np.sin(2 * np.pi * dow / 7)
    features['dow_cos'] = np.cos(2 * np.pi * dow / 7)
    dom = dates.dt.day
    features['dom_sin'] = np.sin(2 * np.pi * dom / 31)
    features['dom_cos'] = np.cos(2 * np.pi * dom / 31)
    hour = dates.dt.hour
    features['hour_sin'] = np.sin(2 * np.pi * hour / 24)
    features['hour_cos'] = np.cos(2 * np.pi * hour / 24)
    features['is_expense'] = (df['type'] == 'expense').astype(float)
    return features

anom_features = build_app_features(synth_txns)
anom_labels = synth_txns['is_anomaly'].values.astype(bool)
INPUT_DIM_ANOM = anom_features.shape[1]
print(f'Feature matrix: {anom_features.shape}')

X_normal = anom_features[~anom_labels].values
X_anomaly = anom_features[anom_labels].values
print(f'Normal: {len(X_normal)}, Anomaly: {len(X_anomaly)}')

scaler_anom = StandardScaler()
X_normal_scaled = scaler_anom.fit_transform(X_normal)
X_anomaly_scaled = scaler_anom.transform(X_anomaly)

np.random.seed(42)
n_val = int(len(X_normal_scaled) * 0.15)
indices = np.random.permutation(len(X_normal_scaled))
X_train_anom = X_normal_scaled[indices[n_val:]]
X_val_anom = X_normal_scaled[indices[:n_val]]

print(f'Train: {len(X_train_anom)}, Val: {len(X_val_anom)}')

# Build autoencoder
encoder_input = tf.keras.Input(shape=(INPUT_DIM_ANOM,))
x = tf.keras.layers.Dense(32, activation='relu')(encoder_input)
x = tf.keras.layers.Dense(16, activation='relu')(x)
bottleneck = tf.keras.layers.Dense(8, activation='relu', name='bottleneck')(x)
x = tf.keras.layers.Dense(16, activation='relu')(bottleneck)
x = tf.keras.layers.Dense(32, activation='relu')(x)
decoder_output = tf.keras.layers.Dense(INPUT_DIM_ANOM, activation='linear')(x)

autoencoder = tf.keras.Model(encoder_input, decoder_output, name='anomaly_autoencoder')
autoencoder.compile(optimizer='adam', loss='mse')

print('Training autoencoder...')
history_anom = autoencoder.fit(
    X_train_anom, X_train_anom,
    validation_data=(X_val_anom, X_val_anom),
    epochs=100, batch_size=32,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True, monitor='val_loss'),
        tf.keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=5, monitor='val_loss'),
    ],
    verbose=1,
)

# Compute errors
def compute_reconstruction_error(model, X):
    X_pred = model.predict(X, verbose=0)
    return np.mean((X - X_pred) ** 2, axis=1)

errors_normal_val = compute_reconstruction_error(autoencoder, X_val_anom)
errors_anomaly = compute_reconstruction_error(autoencoder, X_anomaly_scaled)
errors_normal_train = compute_reconstruction_error(autoencoder, X_train_anom)

print(f'Normal val error:  mean={errors_normal_val.mean():.6f}, std={errors_normal_val.std():.6f}')
print(f'Anomaly error:     mean={errors_anomaly.mean():.6f}, std={errors_anomaly.std():.6f}')
print(f'Separation: {errors_anomaly.mean() / errors_normal_val.mean():.1f}x')

# Find best threshold
all_errors = np.concatenate([errors_normal_val, errors_anomaly])
all_labels = np.concatenate([np.zeros(len(errors_normal_val)), np.ones(len(errors_anomaly))])
auc = roc_auc_score(all_labels, all_errors)
print(f'AUC-ROC: {auc:.4f}')

best_f1 = 0
best_threshold = 0
for percentile in range(90, 100):
    threshold = np.percentile(errors_normal_val, percentile)
    y_pred_anom = (all_errors > threshold).astype(int)
    f1 = f1_score(all_labels, y_pred_anom)
    if f1 > best_f1:
        best_f1 = f1
        best_threshold = threshold
print(f'Best threshold: {best_threshold:.6f} (F1: {best_f1:.3f})')

# Export
autoencoder.save('../models/saved/anomaly_autoencoder_keras.keras')
tflite_meta_anom = export_keras_to_tflite(autoencoder, '../models/tflite/anomaly_detector.tflite', quantize=True)

anomaly_config = {
    'input_dim': INPUT_DIM_ANOM,
    'feature_names': list(anom_features.columns),
    'scaler': {
        'feature_names': list(anom_features.columns),
        'mean': scaler_anom.mean_.tolist(),
        'std': scaler_anom.scale_.tolist(),
    },
    'threshold': float(best_threshold),
    'normal_error_mean': float(errors_normal_train.mean()),
    'normal_error_std': float(errors_normal_train.std()),
    'metrics': {'auc_roc': float(auc), 'best_f1': float(best_f1)},
}
with open('../models/tflite/anomaly_config.json', 'w') as f:
    json.dump(anomaly_config, f, indent=2)

print('\n[OK] Anomaly detector trained and exported!')

# ============================================================
# NOTEBOOK 04: SPENDING FORECAST
# ============================================================
print('\n' + '='*60)
print('NOTEBOOK 04: SPENDING FORECAST')
print('='*60)

daily = pd.read_csv('../data/processed/daily_spending.csv')
daily['date'] = pd.to_datetime(daily['date'])
values = daily['daily_total'].values.astype(np.float32)
print(f'Daily spending: {len(values)} days')

# Need enough data for LSTM. If real data is short, augment with synthetic
if len(values) < 100:
    print('Augmenting time series with synthetic data...')
    synth_daily = generate_synthetic_transactions(n=5000, start_date='2022-01-01', end_date='2024-12-31', seed=42)
    synth_daily = synth_daily[synth_daily['type'] == 'expense']
    synth_daily['date'] = pd.to_datetime(synth_daily['date'])
    synth_daily_totals = synth_daily.groupby('date')['amount'].sum().reset_index()
    synth_daily_totals.columns = ['date', 'daily_total']
    dr = pd.date_range(synth_daily_totals['date'].min(), synth_daily_totals['date'].max())
    synth_daily_totals = synth_daily_totals.set_index('date').reindex(dr, fill_value=0).reset_index()
    synth_daily_totals.columns = ['date', 'daily_total']
    values = synth_daily_totals['daily_total'].values.astype(np.float32)
    print(f'Augmented to {len(values)} days')

# MinMaxScaler
from sklearn.preprocessing import MinMaxScaler
scaler_fc = MinMaxScaler()
values_scaled = scaler_fc.fit_transform(values.reshape(-1, 1)).flatten()

LOOKBACK = 30
HORIZON = 7

# Create sliding windows
X_fc, y_fc = [], []
for i in range(len(values_scaled) - LOOKBACK - HORIZON + 1):
    X_fc.append(values_scaled[i:i + LOOKBACK])
    y_fc.append(values_scaled[i + LOOKBACK:i + LOOKBACK + HORIZON])
X_fc = np.array(X_fc).reshape(-1, LOOKBACK, 1).astype(np.float32)
y_fc = np.array(y_fc).astype(np.float32)
print(f'Windows: {X_fc.shape[0]}, Input: {X_fc.shape}, Target: {y_fc.shape}')

# Chronological split (no shuffle)
split_idx = int(len(X_fc) * 0.8)
X_train_fc, X_test_fc = X_fc[:split_idx], X_fc[split_idx:]
y_train_fc, y_test_fc = y_fc[:split_idx], y_fc[split_idx:]
print(f'Train: {len(X_train_fc)}, Test: {len(X_test_fc)}')

# LSTM model
fc_model = tf.keras.Sequential([
    tf.keras.layers.LSTM(32, input_shape=(LOOKBACK, 1)),
    tf.keras.layers.Dense(16, activation='relu'),
    tf.keras.layers.Dense(HORIZON),
])
fc_model.compile(optimizer='adam', loss='mse', metrics=['mae'])

print('Training forecaster...')
history_fc = fc_model.fit(
    X_train_fc, y_train_fc,
    validation_split=0.15, epochs=50, batch_size=32,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True, monitor='val_loss'),
    ],
    verbose=1,
)

# Evaluate
y_pred_fc = fc_model.predict(X_test_fc, verbose=0)
# Inverse transform for real metrics
y_test_real = scaler_fc.inverse_transform(y_test_fc.reshape(-1, 1)).reshape(y_test_fc.shape)
y_pred_real = scaler_fc.inverse_transform(y_pred_fc.reshape(-1, 1)).reshape(y_pred_fc.shape)

print('\nForecast Metrics (per-day average):')
fc_metrics = print_regression_metrics(y_test_real.flatten(), y_pred_real.flatten())

# Export
fc_model.save('../models/saved/forecast_keras.keras')
tflite_meta_fc = export_keras_to_tflite(fc_model, '../models/tflite/forecast.tflite', quantize=True)

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

df_sav = pd.read_csv('../data/processed/savings_train.csv')
print(f'Savings dataset: {len(df_sav)} rows')

# Feature engineering
def engineer_savings_features(df):
    features = pd.DataFrame()
    if 'expense_ratio' in df.columns:
        features['expense_ratio'] = df['expense_ratio']
    else:
        features['expense_ratio'] = df['monthly_expenses_usd'] / df['monthly_income_usd'].clip(lower=1)
    if 'savings_rate' in df.columns:
        features['savings_rate'] = df['savings_rate']
    else:
        features['savings_rate'] = 1.0 - features['expense_ratio']
    features['discretionary_ratio'] = features['expense_ratio'] * 0.4
    features['essential_ratio'] = features['expense_ratio'] * 0.6
    if 'debt_to_income_ratio' in df.columns:
        features['credit_util'] = df['debt_to_income_ratio'].clip(upper=1.0)
    else:
        features['credit_util'] = 0.3
    return features

features_sav = engineer_savings_features(df_sav)

def label_risk(row):
    if row['savings_rate'] > 0.20:
        return 0  # healthy
    elif row['savings_rate'] > 0.05:
        return 1  # moderate
    else:
        return 2  # at_risk

labels_sav = features_sav.apply(label_risk, axis=1).values
RISK_LABELS = ['healthy', 'moderate', 'at_risk']
print('Risk distribution:')
for i, label in enumerate(RISK_LABELS):
    print(f'  {label}: {(labels_sav == i).sum()} ({(labels_sav == i).mean():.1%})')

X_sav = features_sav.values.astype(np.float32)
X_train_sav, X_test_sav, y_train_sav, y_test_sav = train_test_split(
    X_sav, labels_sav, test_size=0.2, random_state=42, stratify=labels_sav
)

scaler_sav = StandardScaler()
X_train_sav_s = scaler_sav.fit_transform(X_train_sav)
X_test_sav_s = scaler_sav.transform(X_test_sav)

# Keras model
INPUT_DIM_SAV = X_train_sav_s.shape[1]
NUM_CLASSES_SAV = 3

keras_sav = tf.keras.Sequential([
    tf.keras.layers.Dense(16, activation='relu', input_shape=(INPUT_DIM_SAV,)),
    tf.keras.layers.Dense(8, activation='relu'),
    tf.keras.layers.Dense(NUM_CLASSES_SAV, activation='softmax'),
])
keras_sav.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

print('Training savings advisor...')
history_sav = keras_sav.fit(
    X_train_sav_s, y_train_sav,
    validation_split=0.15, epochs=50, batch_size=32,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True, monitor='val_accuracy'),
    ],
    verbose=1,
)

y_pred_sav = np.argmax(keras_sav.predict(X_test_sav_s, verbose=0), axis=1)
sav_acc = accuracy_score(y_test_sav, y_pred_sav)
print(f'Savings classifier accuracy: {sav_acc:.4f}')

# Export
keras_sav.save('../models/saved/savings_advisor_keras.keras')
export_keras_to_tflite(keras_sav, '../models/tflite/savings_advisor.tflite', quantize=True)

savings_config = {
    'input_dim': INPUT_DIM_SAV, 'num_classes': NUM_CLASSES_SAV,
    'risk_labels': RISK_LABELS,
    'feature_names': list(features_sav.columns),
    'scaler': {'mean': scaler_sav.mean_.tolist(), 'std': scaler_sav.scale_.tolist()},
    'metrics': {'accuracy': float(sav_acc)},
}
with open('../models/tflite/savings_config.json', 'w') as f:
    json.dump(savings_config, f, indent=2)

# Recommendation templates
recommendations = {
    "risk_levels": {
        "healthy": {"title": "Great Financial Health", "description": "You're saving well! Here are ways to optimize further.", "icon": "emoji_events"},
        "moderate": {"title": "Room for Improvement", "description": "Your spending is manageable, but you could save more.", "icon": "trending_up"},
        "at_risk": {"title": "Action Needed", "description": "Your expenses are close to or exceeding your income.", "icon": "warning"},
    },
    "rules": [
        {"id": "high_dining", "condition": "category_ratio.dining > 0.15", "title": "Reduce Dining Expenses", "description": "Dining makes up {ratio}% of your spending. Try meal prepping to cut costs by 30-50%.", "category": "dining", "threshold": 0.15, "priority": "high", "potential_savings": 0.3},
        {"id": "high_entertainment", "condition": "category_ratio.entertainment > 0.10", "title": "Optimize Entertainment Budget", "description": "Entertainment is {ratio}% of spending. Consider free alternatives or shared subscriptions.", "category": "entertainment", "threshold": 0.10, "priority": "medium", "potential_savings": 0.25},
        {"id": "high_shopping", "condition": "category_ratio.shopping > 0.20", "title": "Curb Shopping Spending", "description": "Shopping is {ratio}% of your expenses. Try a 24-hour rule before non-essential purchases.", "category": "shopping", "threshold": 0.20, "priority": "high", "potential_savings": 0.35},
        {"id": "high_transport", "condition": "category_ratio.transport > 0.15", "title": "Lower Transport Costs", "description": "Transport is {ratio}% of spending. Consider carpooling, public transit, or biking.", "category": "transport", "threshold": 0.15, "priority": "medium", "potential_savings": 0.20},
        {"id": "high_groceries", "condition": "category_ratio.groceries > 0.25", "title": "Optimize Grocery Budget", "description": "Groceries are {ratio}% of spending. Plan meals, buy in bulk, and use coupons.", "category": "groceries", "threshold": 0.25, "priority": "medium", "potential_savings": 0.15},
        {"id": "no_savings", "condition": "savings_rate < 0.05", "title": "Start an Emergency Fund", "description": "You're saving less than 5%. Aim to save at least 10% of income as a safety net.", "category": None, "threshold": 0.05, "priority": "critical", "potential_savings": None},
        {"id": "spending_increase", "condition": "month_over_month_increase > 0.20", "title": "Spending Increased Significantly", "description": "Your spending increased {increase}% from last month. Review recent purchases for non-essentials.", "category": None, "threshold": 0.20, "priority": "high", "potential_savings": None},
        {"id": "high_utilities", "condition": "category_ratio.utilities > 0.12", "title": "Reduce Utility Bills", "description": "Utilities are {ratio}% of spending. Check for better plans, reduce usage, or switch providers.", "category": "utilities", "threshold": 0.12, "priority": "low", "potential_savings": 0.10},
    ]
}
with open('../models/tflite/recommendation_templates.json', 'w') as f:
    json.dump(recommendations, f, indent=2)

print('\n[OK] Savings advisor trained and exported!')

# ============================================================
# SUMMARY
# ============================================================
print('\n' + '='*60)
print('ALL MODELS TRAINED AND EXPORTED')
print('='*60)

import os
tflite_dir = '../models/tflite'
print(f'\nExported files in {tflite_dir}:')
for f in sorted(os.listdir(tflite_dir)):
    size = os.path.getsize(os.path.join(tflite_dir, f))
    print(f'  {f:45s} {size/1024:>8.1f} KB')

print(f'\nCopy to Flutter:')
print(f'  cp {tflite_dir}/* ../../app/assets/models/')
