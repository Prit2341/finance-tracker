# ML Pipeline

## Overview

The ML pipeline trains four TensorFlow models on public financial datasets, exports them as quantized TFLite files, and ships them with the Flutter app for on-device inference.

```
Kaggle Data → Preprocessing → Training → Evaluation → TFLite Export → Flutter Assets
```

## Notebooks

Run notebooks in order (`00` → `05`). Each is self-contained with clear sections.

### 00 — Data Exploration

Exploratory data analysis on Kaggle financial transaction datasets.

- Distribution of amounts, categories, dates
- Missing value analysis
- Category balance assessment
- Merchant name patterns

### 01 — Data Preprocessing

Cleans raw data and engineers features for all downstream models.

- Text normalization (lowercase, remove special characters)
- Category mapping to app's 12-category enum
- Feature extraction: cyclical time features, log amounts
- Train/test splits saved to `data/processed/`
- Anomaly injection (~2%) for anomaly detection training

**App Categories**: groceries, dining, transport, utilities, entertainment, healthcare, shopping, rent, salary, freelance, transfer, other

### 02 — Auto-Categorization (LSTM Text Classifier)

Trains a text classifier that predicts transaction category from merchant name.

**Architecture**:
```
Input(merchant_name) → Tokenizer(vocab=2000, maxlen=20)
    → Embedding(64) → LSTM(32) → Dense(64, relu) → Dropout(0.3)
    → Dense(12, softmax)
```

**Training**:
- 80/20 stratified split
- Early stopping on val_accuracy (patience=10)
- Adam optimizer, sparse categorical crossentropy

**Export**:
- `categorizer.tflite` — INT8 quantized model (< 500 KB)
- `tokenizer.json` — word→index mapping for Dart parity
- `categorizer_config.json` — vocab size, max length, category labels

**Dart Parity**: `categorizer.dart` replicates Python's tokenization exactly — lowercase, split on spaces, map words to indices using `tokenizer.json`, pad/truncate to `maxlen`.

### 03 — Anomaly Detection (Autoencoder)

Trains a dense autoencoder to detect unusual transactions via reconstruction error.

**Architecture**:
```
Input(20) → Dense(32, relu) → Dense(16, relu) → Dense(8, relu)
    → Dense(16, relu) → Dense(32, relu) → Dense(20, sigmoid)
```

**Features** (20-dimensional):
| Feature | Dims | Description |
|---------|------|-------------|
| log_amount | 1 | log1p(amount) |
| category_onehot | 12 | One-hot encoded category |
| day_of_week_sin/cos | 2 | Cyclical day encoding |
| day_of_month_sin/cos | 2 | Cyclical month day encoding |
| hour_sin/cos | 2 | Cyclical hour encoding |
| is_expense | 1 | Binary flag |

**Training**:
- Trained on **normal transactions only** (no anomalies)
- MSE loss, Adam optimizer
- Threshold set by optimizing F1 score on validation set with injected anomalies

**Export**:
- `anomaly_detector.tflite` — quantized autoencoder
- `anomaly_config.json` — scaler mean/std, threshold, feature names

**Scoring**: `anomaly_score = MSE(input, reconstruction)`. If score > threshold → anomaly. Severity is based on z-score relative to training distribution.

### 04 — Spending Forecast (LSTM Time Series)

Trains an LSTM to predict 7-day spending from 30-day history.

**Architecture**:
```
Input(30, 1) → LSTM(32, return_sequences=False)
    → Dense(16, relu) → Dense(7)
```

**Data Preparation**:
- Aggregate daily expense totals
- MinMaxScaler normalization
- Sliding window: 30-day input → 7-day target
- 80/20 chronological split (no random shuffle)

**Baselines**:
- Prophet (Facebook) — fitted for comparison
- Naive (repeat last week) — lower bound

**Export**:
- `forecast.tflite` — quantized LSTM
- `forecast_config.json` — lookback window, horizon, scaler min/max

**Cold Start**: Flutter's `Forecaster` returns `null` when < 30 days of transaction history exist. UI shows a progress indicator.

### 05 — Savings Recommendations (Decision Tree + Rules)

Two-part system: ML risk classifier + rule-based recommendation engine.

**Risk Classifier**:
```
Input(5) → Dense(16, relu) → Dense(8, relu) → Dense(3, softmax)
```

Features: expense_ratio, savings_rate, discretionary_ratio, essential_ratio, credit_util

Risk levels:
| Level | Savings Rate | Description |
|-------|-------------|-------------|
| healthy | > 20% | Good financial habits |
| moderate | 5–20% | Room for improvement |
| at_risk | < 5% | Spending close to income |

**Rule Engine** (8 rules):
| Rule | Trigger | Priority |
|------|---------|----------|
| no_savings | savings_rate < 5% | critical |
| spending_increase | month-over-month > 20% | high |
| high_dining | dining > 15% of expenses | high |
| high_shopping | shopping > 20% | high |
| high_entertainment | entertainment > 10% | medium |
| high_transport | transport > 15% | medium |
| high_groceries | groceries > 25% | medium |
| high_utilities | utilities > 12% | low |

**Export**:
- `savings_advisor.tflite` — risk classifier
- `savings_config.json` — scaler params, feature names
- `recommendation_templates.json` — rule definitions + risk level descriptions

**Dual Mode**: Flutter's `SavingsAdvisor` uses the TFLite model when available, falls back to simple threshold rules (`savings_rate > 20%` = healthy, etc.).

## Shared Utilities (`ml/src/`)

| File | Purpose |
|------|---------|
| `preprocessing.py` | Text cleaning, category mapping, APP_CATEGORIES constant |
| `export_tflite.py` | `export_keras_to_tflite()` with INT8 quantization, `verify_tflite_model()` |
| `data_generator.py` | Synthetic transaction generation, anomaly injection |
| `evaluate.py` | Classification reports, confusion matrices, time series metrics |

## Exporting Models to Flutter

After training all models:

```bash
# Copy TFLite models
cp ml/models/tflite/categorizer.tflite       app/assets/models/
cp ml/models/tflite/anomaly_detector.tflite  app/assets/models/
cp ml/models/tflite/forecast.tflite          app/assets/models/
cp ml/models/tflite/savings_advisor.tflite   app/assets/models/

# Copy config files
cp ml/models/tflite/tokenizer.json                 app/assets/models/
cp ml/models/tflite/categorizer_config.json         app/assets/models/
cp ml/models/tflite/anomaly_config.json             app/assets/models/
cp ml/models/tflite/forecast_config.json            app/assets/models/
cp ml/models/tflite/savings_config.json             app/assets/models/
cp ml/models/tflite/recommendation_templates.json   app/assets/models/
```

## Reproducibility

All notebooks use fixed random seeds (`random_state=42`) and save intermediate data to `data/processed/`. Model training is deterministic given the same input data.

Requirements: see `ml/requirements.txt` for pinned Python dependencies.
