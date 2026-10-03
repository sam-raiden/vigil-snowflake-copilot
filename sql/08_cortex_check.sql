SELECT CURRENT_ACCOUNT() acct, CURRENT_REGION() region, SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b','Reply with the single word OK') AS cortex_complete;
