"""
AWS Vector Store package for MarketPulse.

Components:
  - bedrock_embedder : generates embeddings via Amazon Bedrock Titan
  - opensearch_client: indexes/queries Amazon OpenSearch Serverless
  - rag_context      : builds retrieval-augmented context for Gemini
  - sync_worker      : orchestrates post-pipeline vector sync
"""
