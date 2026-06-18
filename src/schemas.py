from pydantic import BaseModel, Field
from typing import Literal


class PredictionRequest(BaseModel):
    # Le texte à analyser : obligatoire, entre 1 et 5000 caractères
    text: str = Field(..., min_length=1, max_length=5000)


class PredictionResponse(BaseModel):
    # Label retourné par le modèle
    label: Literal["POSITIVE", "NEGATIVE", "NEUTRAL"]

    # Score de confiance entre 0.0 et 1.0
    score: float

    # Texte original pour traçabilité
    text: str
    