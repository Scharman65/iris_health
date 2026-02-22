from pydantic import BaseModel
from typing import Optional


class EyeAnalysis(BaseModel):
    brightness: float
    glare: float
    sharpness: float
    diagnosis: str
    recommendations: str


class AnalysisResponse(BaseModel):
    left: EyeAnalysis
    right: EyeAnalysis
    pdf_url: Optional[str] = None
    text_summary: Optional[str] = None
