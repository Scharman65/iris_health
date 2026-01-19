from iris_ai_server.models.response_models import EyeAnalysis


def evaluate_iris(img):
    """
    Временная заглушка анализа радужки.
    Возвращает объект EyeAnalysis строго по модели.
    """

    return EyeAnalysis(
        brightness=0.75,
        glare=0.00,
        sharpness=1.00,
        diagnosis=(
            "Спокойная структура радужки. "
            "Признаков выраженной патологии не выявлено."
        ),
        recommendations=(
            "Поддерживающий режим: питьевой баланс, "
            "витамины группы B, контроль сна."
        )
    )
