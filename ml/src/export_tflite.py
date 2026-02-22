"""
TFLite model export utilities for Finance Tracker.
Handles conversion, quantization, and metadata export.
"""

import json
import numpy as np
import tensorflow as tf


def export_keras_to_tflite(
    model: tf.keras.Model,
    output_path: str,
    quantize: bool = True,
) -> dict:
    """
    Convert a Keras model to TFLite format with optional INT8 quantization.
    Returns metadata about the exported model.
    """
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    size_kb = len(tflite_model) / 1024
    metadata = {
        'output_path': output_path,
        'size_kb': round(size_kb, 2),
        'quantized': quantize,
        'input_shape': model.input_shape,
        'output_shape': model.output_shape,
    }

    print(f'Model exported to {output_path} ({size_kb:.1f} KB)')
    return metadata


def export_tokenizer(word_index: dict, output_path: str):
    """Export tokenizer word_index as JSON for Flutter."""
    with open(output_path, 'w') as f:
        json.dump(word_index, f, indent=2)
    print(f'Tokenizer exported to {output_path} ({len(word_index)} words)')


def export_category_labels(categories: list, output_path: str):
    """Export ordered category label list as JSON for Flutter."""
    with open(output_path, 'w') as f:
        json.dump(categories, f, indent=2)
    print(f'Category labels exported to {output_path} ({len(categories)} categories)')


def export_anomaly_params(params: dict, output_path: str):
    """Export anomaly detection parameters (mean/std per category) as JSON."""
    # Convert numpy types to native Python for JSON serialization
    serializable = {}
    for key, value in params.items():
        if isinstance(value, dict):
            serializable[key] = {
                k: float(v) if isinstance(v, (np.floating, np.integer)) else v
                for k, v in value.items()
            }
        else:
            serializable[key] = value

    with open(output_path, 'w') as f:
        json.dump(serializable, f, indent=2)
    print(f'Anomaly params exported to {output_path}')


def verify_tflite_model(tflite_path: str, sample_input: np.ndarray) -> np.ndarray:
    """Load a TFLite model and run inference on a sample input for verification."""
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    interpreter.set_tensor(input_details[0]['index'], sample_input)
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]['index'])

    print(f'TFLite verification:')
    print(f'  Input shape: {input_details[0]["shape"]}')
    print(f'  Output shape: {output_details[0]["shape"]}')
    print(f'  Output sample: {output[0][:5]}...')

    return output
