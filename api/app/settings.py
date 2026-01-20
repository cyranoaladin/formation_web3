from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    RBK_ENV: str = "dev"
    MONGODB_URI: str = "mongodb://mongo:27017"
    MONGODB_DB: str = "rbk_labs"

    # RAG
    RBK_VECTOR_BACKEND: str = "atlas"
    ATLAS_SEARCH_INDEX_NAME: str = "rbk_chunks_v1"

settings = Settings()
