from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
from bert_score import score
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update with your frontend's domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple root route to avoid 404 at "/"
@app.get("/")
def root():
    return {"message": "API is running"}

class MatchRequest(BaseModel):
    query: str
    candidates: List[str]
    top_n: int = 10

class MatchResult(BaseModel):
    sentence: str
    score: float

@app.post("/match")
def find_top_matches(request: MatchRequest):
    print("Query:", request.query)
    print("Candidates:", request.candidates)
    P, R, F1 = score(
        [request.query] * len(request.candidates),
        request.candidates,
        model_type="bert-base-multilingual-cased",
        lang="th"
    )
    top_indices = F1.argsort(descending=True)[:request.top_n]
    top_matches = [
        {"sentence": request.candidates[i], "score": round(F1[i].item(), 4)}
        for i in top_indices
    ]
    return {"query": request.query, "top_matches": top_matches}
