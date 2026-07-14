#!/usr/bin/env python3
"""
AWS OpenSearch Serverless Setup Script for MarketPulse.

Run this ONCE after configuring your AWS credentials in .env:
    python setup_aws.py

What it does:
  1. Creates an OpenSearch Serverless collection: marketpulse-vectors
  2. Attaches encryption, network, and data access policies
  3. Waits for the collection to become ACTIVE
  4. Prints the collection endpoint to add to your .env

Requirements:
  - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION set in .env
  - IAM user has AmazonOpenSearchServiceFullAccess policy attached

Cost: OpenSearch Serverless has a minimum of 2 OCUs (~$0.24/hr).
      For development, delete the collection when not in use.
"""

import json
import os
import sys
import time

from dotenv import load_dotenv

load_dotenv()

AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
COLLECTION_NAME = "marketpulse-vectors"

if not AWS_ACCESS_KEY_ID or not AWS_SECRET_ACCESS_KEY:
    print("❌  AWS credentials not found in .env")
    print("    Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
    sys.exit(1)

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("❌  boto3 not installed. Run: pip install boto3")
    sys.exit(1)


def get_account_id(session):
    sts = session.client("sts")
    return sts.get_caller_identity()["Account"]


def setup_opensearch_serverless():
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION,
    )

    account_id = get_account_id(session)
    print(f"✅  AWS Account: {account_id}")
    print(f"✅  Region: {AWS_REGION}")

    client = session.client("opensearchserverless")

    # ── 1. Encryption policy ─────────────────────────────────────────────────
    print("\n🔐  Creating encryption policy...")
    enc_policy = {
        "Rules": [
            {"Resource": [f"collection/{COLLECTION_NAME}"], "ResourceType": "collection"}
        ],
        "AWSOwnedKey": True,
    }
    try:
        client.create_security_policy(
            name=f"{COLLECTION_NAME}-enc",
            type="encryption",
            policy=json.dumps(enc_policy),
            description="MarketPulse vector store encryption policy",
        )
        print("   ✓ Encryption policy created")
    except ClientError as e:
        if "ConflictException" in str(e):
            print("   ⚠ Encryption policy already exists – skipping")
        else:
            raise

    # ── 2. Network policy (public access) ────────────────────────────────────
    print("🌐  Creating network policy...")
    net_policy = [
        {
            "Rules": [
                {
                    "Resource": [f"collection/{COLLECTION_NAME}"],
                    "ResourceType": "collection",
                },
                {
                    "Resource": [f"collection/{COLLECTION_NAME}"],
                    "ResourceType": "dashboard",
                },
            ],
            "AllowFromPublic": True,
        }
    ]
    try:
        client.create_security_policy(
            name=f"{COLLECTION_NAME}-net",
            type="network",
            policy=json.dumps(net_policy),
            description="MarketPulse vector store network policy",
        )
        print("   ✓ Network policy created")
    except ClientError as e:
        if "ConflictException" in str(e):
            print("   ⚠ Network policy already exists – skipping")
        else:
            raise

    # ── 3. Data access policy ────────────────────────────────────────────────
    print("🔑  Creating data access policy...")
    data_policy = [
        {
            "Rules": [
                {
                    "Resource": [f"collection/{COLLECTION_NAME}"],
                    "Permission": [
                        "aoss:CreateCollectionItems",
                        "aoss:DeleteCollectionItems",
                        "aoss:UpdateCollectionItems",
                        "aoss:DescribeCollectionItems",
                    ],
                    "ResourceType": "collection",
                },
                {
                    "Resource": [f"index/{COLLECTION_NAME}/*"],
                    "Permission": [
                        "aoss:CreateIndex",
                        "aoss:DeleteIndex",
                        "aoss:UpdateIndex",
                        "aoss:DescribeIndex",
                        "aoss:ReadDocument",
                        "aoss:WriteDocument",
                    ],
                    "ResourceType": "index",
                },
            ],
            "Principal": [f"arn:aws:iam::{account_id}:root"],
            "Description": "MarketPulse backend full access",
        }
    ]
    try:
        client.create_access_policy(
            name=f"{COLLECTION_NAME}-access",
            type="data",
            policy=json.dumps(data_policy),
            description="MarketPulse vector store data access policy",
        )
        print("   ✓ Data access policy created")
    except ClientError as e:
        if "ConflictException" in str(e):
            print("   ⚠ Data access policy already exists – skipping")
        else:
            raise

    # ── 4. Create collection ─────────────────────────────────────────────────
    print(f"\n🗄️   Creating OpenSearch Serverless collection: {COLLECTION_NAME}...")
    try:
        response = client.create_collection(
            name=COLLECTION_NAME,
            type="VECTORSEARCH",
            description="MarketPulse news & stock vector store (k-NN indices)",
        )
        collection_id = response["createCollectionDetail"]["id"]
        print(f"   ✓ Collection created: id={collection_id}")
    except ClientError as e:
        if "ConflictException" in str(e):
            print("   ⚠ Collection already exists – fetching endpoint...")
            collections = client.list_collections(
                collectionFilters={"name": COLLECTION_NAME}
            )["collectionSummaries"]
            if collections:
                collection_id = collections[0]["id"]
            else:
                print("   ❌ Could not find existing collection")
                sys.exit(1)
        else:
            raise

    # ── 5. Wait for ACTIVE ───────────────────────────────────────────────────
    print("\n⏳  Waiting for collection to become ACTIVE (this may take 3-5 minutes)...")
    endpoint = None
    for attempt in range(60):
        time.sleep(10)
        resp = client.batch_get_collection(ids=[collection_id])
        details = resp.get("collectionDetails", [{}])[0]
        status = details.get("status", "UNKNOWN")
        print(f"   [{attempt + 1}/60] Status: {status}")
        if status == "ACTIVE":
            endpoint = details.get("collectionEndpoint", "")
            break
        if status == "FAILED":
            print("   ❌ Collection creation FAILED")
            sys.exit(1)

    if not endpoint:
        print("   ❌ Timed out waiting for collection")
        sys.exit(1)

    print(f"\n✅  Collection ACTIVE!")
    print(f"\n{'='*60}")
    print(f"Add the following to your .env file:")
    print(f"{'='*60}")
    print(f"OPENSEARCH_ENDPOINT={endpoint}")
    print(f"{'='*60}")
    print()
    print("Next steps:")
    print("  1. Add OPENSEARCH_ENDPOINT to .env (and to Render/EC2 env vars)")
    print("  2. Restart the backend service")
    print("  3. The k-NN indices will be auto-created on first startup")
    print("  4. Go to Admin → Vector Training to start syncing articles")
    print()

    return endpoint


if __name__ == "__main__":
    setup_opensearch_serverless()
