# Finance Tracker

A personal finance tracking app built with Flutter that runs entirely on your device — no internet, no cloud, no accounts required. It uses on-device machine learning to automatically categorize your spending, detect unusual transactions, forecast future spending, and give savings advice.

---

## What Does This App Do?

You add your bank accounts and transactions. The app then:

- **Tracks your money** across multiple bank accounts
- **Categorizes transactions automatically** using AI (groceries, food, transport, etc.)
- **Alerts you** when a transaction looks unusual compared to your normal spending
- **Predicts** how much you'll spend in the next 7 days
- **Tracks subscriptions** and tells you what's due and when
- **Monitors budgets** and warns you before you overspend
- **Gives savings tips** based on your spending patterns

Everything stays on your phone. No data is ever sent anywhere.

---

## Features

### Dashboard (Home)
- Greeting with your name and time of day
- Total balance across all accounts
- Monthly income vs expenses summary
- Quick action buttons (Add transaction, Accounts, Insights, Subscriptions)
- Spending forecast strip — predicted spending for the next 7 days
- Subscriptions strip — upcoming bills at a glance
- Budget strip — how much of your monthly budget is left
- Recent transactions list
- Spending charts (pie chart by category, trend line over time)
- Anomaly alert banner when unusual spending is detected

### Transactions
- Add, edit, delete transactions
- Auto-categorization — type the merchant name and the AI suggests the category
- Search by merchant name
- Filter by category or type (income / expense)
- Transactions grouped by date
- Swipe to delete

### Accounts
- Add multiple bank accounts
- Track total balance, usable amount, savings portion, minimum balance
- Visual balance bar showing how your money is split
- Warning when balance drops near the minimum

### Analytics (3 tabs)
- **Anomalies** — list of flagged unusual transactions with anomaly scores
- **Forecast** — 7-day spending prediction chart
- **Savings Advisor** — spending risk rating (Healthy / Moderate / At Risk) with actionable tips

### Subscriptions
- Track recurring payments (Netflix, Spotify, rent, etc.)
- Set billing cycle (monthly, weekly, yearly, etc.)
- See next due date and monthly total cost

### Budgets
- Set monthly spending limits per category
- Progress bars showing how much is spent vs limit
- Color changes to red when over budget

### Settings
- Set your name (used in the greeting)
- Switch between Light and Dark theme (saved across restarts)
- Choose currency (7 options: USD, EUR, GBP, INR, JPY, CAD, AUD)
- Export all transactions to CSV
- View ML model status (loaded / not loaded, version info)

---

## How the Machine Learning Works

The app has four AI models, all running directly on your device using TensorFlow Lite. Here is what each one does and why it exists.

### 1. Auto-Categorizer
**What it does:** When you type a merchant name like "McDonald's" or "Uber", it predicts the category (Food, Transport, etc.) automatically.

**Why:** Manually picking a category every time is tedious. The model handles obvious cases so you don't have to.

**How it works:**
1. You type the merchant name
2. The app cleans the text (lowercase, removes special characters)
3. Converts each word to a number using a vocabulary lookup
4. Feeds the numbers into a small LSTM neural network
5. The network outputs confidence scores for each of the 12 categories
6. If confidence is **≥ 80%**, the category is auto-assigned
7. If below 80%, the top 3 suggestions are shown for you to pick from

**Model:** LSTM Text Classifier — ~500 KB TFLite file

---

### 2. Anomaly Detector
**What it does:** Flags transactions that look unusual compared to your normal spending patterns.

**Why:** Unusual spending could mean an error, fraud, or just a one-off expense worth noticing. The app highlights these so you can review them.

**How it works:**
1. Every transaction is converted into a feature vector (amount, category, day of week, time of month, etc.)
2. An autoencoder neural network tries to reconstruct that vector
3. If the reconstruction is very different from the original (high error), the transaction is unusual
4. Transactions above the error threshold get an anomaly warning icon

**Model:** Autoencoder — ~200 KB TFLite file

---

### 3. Spending Forecaster
**What it does:** Predicts how much you will spend each day for the next 7 days.

**Why:** Knowing what's coming helps you plan. If the forecast shows a heavy spending week, you can adjust.

**How it works:**
1. Takes your last 30 days of daily spending as input
2. Feeds it through an LSTM (good at learning from sequences over time)
3. Outputs 7 predicted daily spending values
4. Shown as a chart in Analytics and as a summary strip on the Dashboard

**Model:** LSTM Time Series — ~300 KB TFLite file

---

### 4. Savings Advisor
**What it does:** Classifies your overall spending health as Healthy, Moderate, or At Risk, and gives specific tips to improve.

**Why:** Raw numbers don't always tell you what to do. This turns your data into simple, actionable advice.

**How it works:**
1. Calculates 5 features from your spending: expense ratio, savings rate, subscription burden, budget adherence, and spending volatility
2. A small neural network classifies these into one of three risk levels
3. A rule engine then picks relevant tips based on which features are out of range

**Model:** Dense classifier — ~100 KB TFLite file

---

### How the App Learns From You (On-Device Retraining)

The categorizer gets smarter over time based on your corrections:

- When you **correct** a suggested category, that correction is saved (weight: 1.0)
- When you **accept** a suggestion without changing it, that's also saved (weight: 0.5)
- After every **50 feedback samples**, the app builds a personalized merchant → category lookup table from your history
- This lookup is tested against a holdout set — if it's more accurate than the current version, it replaces it
- If not more accurate, the old version is kept (safe rollback)
- Result: "McDonald's → Food" is remembered permanently after you confirm it once

This works without internet or cloud servers because it's a weighted lookup table, not gradient-based training — TFLite only does inference, so real neural network training stays in the Python pipeline.

---

## Tech Stack

### Flutter App

| Library | Purpose |
|---|---|
| `flutter_riverpod` | State management across the app |
| `go_router` | Navigation between screens |
| `sqflite` | Local SQLite database |
| `tflite_flutter` | Running ML models on-device |
| `fl_chart` | Interactive charts |
| `google_fonts` | Space Grotesk + Inter fonts |
| `shared_preferences` | Persisting theme, name, currency settings |
| `csv` | Exporting transactions to CSV |
| `intl` | Date and currency formatting |
| `uuid` | Generating unique IDs |
| `path_provider` | Accessing device file system |

### ML Pipeline (Python)

| Library | Purpose |
|---|---|
| TensorFlow 2.16+ | Training models and exporting to TFLite |
| scikit-learn | Preprocessing, baseline comparisons |
| pandas / numpy | Data manipulation |
| Prophet | Forecast baseline comparison |
| matplotlib / seaborn | Visualizing training results |

---

## Architecture

The app follows Clean Architecture with a feature-based folder structure.

```
Presentation Layer  →  Domain Layer  →  Data Layer
(UI + Riverpod)        (Entities)        (SQLite repos)
```

Each feature (transactions, accounts, budgets, etc.) has its own folder with these three layers separated. This makes each feature independent and easy to change without breaking others.

The ML layer sits in `shared/ml/` and is used by the presentation layer through Riverpod providers.

```
User types merchant name
        ↓
Categorizer.predict()          ← TFLite inference
        ↓
Confidence ≥ 80%?
  Yes → auto-assign category
  No  → show top 3 suggestions to user
        ↓
User confirms or corrects
        ↓
TrainingBuffer.add(sample)     ← saved to SQLite
        ↓
Every 50 samples → Retrainer.retrain()
        ↓
New lookup table built → validated → activated if better
```

---

## Database

SQLite, local only. Schema has evolved through 4 versions:

| Version | What Was Added |
|---|---|
| v1 | `transactions`, `training_buffer`, `model_metadata` |
| v2 | `bank_accounts`, `account_id` column on transactions |
| v3 | `subscriptions` |
| v4 | `budgets` |

Migrations run automatically on app update. No data is lost between versions.

---

## Project Structure

```
finance_tracker/
├── app/                          Flutter application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart              MaterialApp, theme, router setup
│   │   ├── core/                 Theme, constants, router, utilities
│   │   ├── features/
│   │   │   ├── dashboard/        Home screen
│   │   │   ├── transactions/     Add, edit, list transactions
│   │   │   ├── accounts/         Bank account management
│   │   │   ├── analytics/        Anomalies, forecast, savings tabs
│   │   │   ├── subscriptions/    Recurring billing tracker
│   │   │   ├── budgets/          Monthly spending limits
│   │   │   ├── settings/         App preferences
│   │   │   └── splash/           Launch screen
│   │   └── shared/
│   │       ├── database/         SQLite schema and migrations
│   │       ├── ml/               All ML integration code
│   │       │   ├── categorizer.dart        Text → category inference
│   │       │   ├── anomaly_detector.dart   Autoencoder scoring
│   │       │   ├── forecaster.dart         LSTM prediction
│   │       │   ├── savings_advisor.dart    Risk classification + tips
│   │       │   ├── training_buffer.dart    Feedback collection
│   │       │   ├── model_manager.dart      Versioning and rollback
│   │       │   └── retrainer.dart          On-device personalization
│   │       └── widgets/          Shared UI components
│   └── assets/
│       ├── models/               .tflite files + config JSON
│       ├── data/                 Seed/reference data
│       └── images/               App logo
├── ml/                           Python ML pipeline
│   ├── notebooks/
│   │   ├── 00_data_exploration.ipynb
│   │   ├── 01_data_preprocessing.ipynb
│   │   ├── 02_auto_categorization.ipynb
│   │   ├── 03_anomaly_detection.ipynb
│   │   ├── 04_spending_forecast.ipynb
│   │   └── 05_savings_recommendations.ipynb
│   ├── src/                      Shared Python utilities
│   │   ├── preprocessing.py
│   │   ├── export_tflite.py
│   │   ├── data_generator.py
│   │   └── evaluate.py
│   ├── data/                     Raw and processed datasets
│   └── models/                   Trained Keras + TFLite exports
└── docs/                         Architecture and ML pipeline docs
```

---

## ML Model Performance

| Model | Accuracy | TFLite Size | Input | Output |
|---|---|---|---|---|
| Auto-Categorizer | ~92% | < 500 KB | Tokenized merchant name (padded to 20 tokens) | 12-class softmax |
| Anomaly Detector | ~95% precision | < 200 KB | 20-dimensional feature vector | Reconstruction error (MSE) |
| Spending Forecaster | ~15% MAE | < 300 KB | 30-day spending history | 7-day prediction |
| Savings Advisor | ~90% | < 100 KB | 5 spending features | 3-class risk label |

All models use INT8 post-training quantization to keep file sizes small.

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.11.0
- Dart SDK ≥ 3.0.0
- Android Studio or VS Code with Flutter extension
- Python 3.10+ (only needed if retraining ML models)

### Run the App

```bash
cd app
flutter pub get
flutter run
```

The app works immediately. ML models are bundled in `assets/models/` so no setup is needed.

### Retrain the ML Models (Optional)

Only needed if you want to retrain the models from scratch.

```bash
# Set up Python environment
python -m venv venv
source venv/bin/activate      # macOS / Linux
venv\Scripts\activate         # Windows

pip install -r ml/requirements.txt

# Run notebooks in order
cd ml/notebooks
jupyter notebook
# Run: 00 → 01 → 02 → 03 → 04 → 05
```

After training, copy the exported models to Flutter assets:

```bash
cp ml/models/tflite/*.tflite app/assets/models/
cp ml/models/tflite/*.json   app/assets/models/
```

Then rebuild the app.

---

## Design

- **Design system:** Material 3
- **Brand color:** `#137FEC` (blue)
- **Fonts:** Space Grotesk (headings) + Inter (body)
- **Themes:** Light and Dark mode, both fully supported
- **Offline only:** No network permission required
