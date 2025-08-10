from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

@app.route('/preprocess', methods=['POST'])
def preprocess():
    left_eye = request.files.get('leftEye')
    right_eye = request.files.get('rightEye')

    if not left_eye or not right_eye:
        return jsonify({'error': 'Нужно загрузить оба изображения: левый и правый глаз'}), 400

    # Имитируем результат анализа
    result = {
        "zones": [
            {
                "organ": "Печень",
                "position": "3:00",
                "findings": "Слабая пигментация, возможен застой желчи",
                "severity": 2
            },
            {
                "organ": "Сердце",
                "position": "12:00",
                "findings": "Норма",
                "severity": 0
            },
            {
                "organ": "Почки",
                "position": "6:00",
                "findings": "Небольшой отёк, возможно обезвоживание",
                "severity": 1
            }
        ],
        "summary": {
            "diagnosis": "Возможны нарушения в работе печени, есть нагрузка на почки",
            "recommendations": [
                "Сделать УЗИ печени",
                "Пить больше воды",
                "Повторить обследование через месяц"
            ]
        }
    }

    return jsonify(result), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050, debug=True)

