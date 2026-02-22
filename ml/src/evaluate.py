"""
Evaluation utilities for Finance Tracker ML models.
"""

import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    f1_score,
    precision_recall_curve,
    mean_absolute_error,
    mean_squared_error,
)


def print_classification_metrics(y_true, y_pred, label_names=None):
    """Print comprehensive classification metrics."""
    acc = accuracy_score(y_true, y_pred)
    f1_weighted = f1_score(y_true, y_pred, average='weighted')
    f1_macro = f1_score(y_true, y_pred, average='macro')

    print(f'Accuracy:         {acc:.4f}')
    print(f'F1 (weighted):    {f1_weighted:.4f}')
    print(f'F1 (macro):       {f1_macro:.4f}')
    print()
    print(classification_report(y_true, y_pred, target_names=label_names))

    return {'accuracy': acc, 'f1_weighted': f1_weighted, 'f1_macro': f1_macro}


def plot_confusion_matrix(y_true, y_pred, label_names=None, figsize=(10, 8)):
    """Plot a styled confusion matrix."""
    cm = confusion_matrix(y_true, y_pred)
    fig, ax = plt.subplots(figsize=figsize)
    sns.heatmap(
        cm, annot=True, fmt='d', cmap='Blues',
        xticklabels=label_names, yticklabels=label_names, ax=ax,
    )
    ax.set_xlabel('Predicted')
    ax.set_ylabel('Actual')
    ax.set_title('Confusion Matrix')
    plt.tight_layout()
    return fig


def plot_training_history(history, metrics=('accuracy', 'loss')):
    """Plot training and validation curves from Keras history."""
    n = len(metrics)
    fig, axes = plt.subplots(1, n, figsize=(6 * n, 4))
    if n == 1:
        axes = [axes]

    for ax, metric in zip(axes, metrics):
        ax.plot(history.history[metric], label=f'Train {metric}')
        val_key = f'val_{metric}'
        if val_key in history.history:
            ax.plot(history.history[val_key], label=f'Val {metric}')
        ax.set_xlabel('Epoch')
        ax.set_ylabel(metric.capitalize())
        ax.set_title(f'{metric.capitalize()} over Epochs')
        ax.legend()
        ax.grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def print_regression_metrics(y_true, y_pred):
    """Print regression metrics for forecasting."""
    mae = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))
    # MAPE (avoid division by zero)
    mask = y_true != 0
    mape = np.mean(np.abs((y_true[mask] - y_pred[mask]) / y_true[mask])) * 100

    print(f'MAE:  ${mae:.2f}')
    print(f'RMSE: ${rmse:.2f}')
    print(f'MAPE: {mape:.1f}%')

    return {'mae': mae, 'rmse': rmse, 'mape': mape}
