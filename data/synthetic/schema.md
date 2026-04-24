# Synthetic Data Schema

## customers.csv

- customer_id
- name
- segment
- risk_level
- consent_status
- email
- national_id

## products.csv

- product_id
- customer_id
- product_type
- product_name
- status

## transactions.csv

- transaction_id
- customer_id
- product_id
- product
- amount
- merchant
- city
- date
- channel
- status

## roles.csv

- role
- can_access_public
- can_access_internal
- can_access_restricted
- can_execute_action

## curated chunks

`chunks_ai_ready.jsonl` contains:

- chunk_id
- document_id
- parent_section_id
- title
- text
- source_page
- metadata
- entities

## graph

`graph_nodes.jsonl` and `graph_edges.jsonl` contain the local graph used by the demo UI.
