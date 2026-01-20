# FieldSlip API - curl Examples for Manual Testing

This document provides example curl commands for testing the FieldSlip API endpoints.

## Prerequisites

- Replace `YOUR_API_KEY` with your actual API key from https://mushroomobserver.org/account/api_keys
- Replace example IDs (observation IDs, project IDs, field slip IDs) with valid IDs from your environment
- The base URL is `https://mushroomobserver.org/api2/field_slip`
- For local testing, use `http://localhost:3000/api2/field_slip` instead

## GET Requests (Read-Only, No Authentication Required)

### 1. Get all field slips (returns IDs only by default)
```bash
curl "https://mushroomobserver.org/api2/field_slip"
```

### 2. Get field slips with low detail
```bash
curl "https://mushroomobserver.org/api2/field_slip?detail=low"
```

### 3. Get field slips with high detail (includes associations)
```bash
curl "https://mushroomobserver.org/api2/field_slip?detail=high"
```

### 4. Get field slips by exact code
```bash
curl "https://mushroomobserver.org/api2/field_slip?code=EOL-0001"
```

### 5. Get field slips by code pattern (partial match)
```bash
curl "https://mushroomobserver.org/api2/field_slip?code_has=EOL"
```

### 6. Get field slips by observation ID
```bash
curl "https://mushroomobserver.org/api2/field_slip?observation=12345"
```

### 7. Get field slips by project ID
```bash
curl "https://mushroomobserver.org/api2/field_slip?project=123"
```

### 8. Get field slips by user (creator)
```bash
curl "https://mushroomobserver.org/api2/field_slip?user=mary"
```

### 9. Get field slips created in a date range
```bash
curl "https://mushroomobserver.org/api2/field_slip?created_at=2024-01-01-2024-12-31"
```

### 10. Get field slips by multiple IDs
```bash
curl "https://mushroomobserver.org/api2/field_slip?id=1,2,3"
```

### 11. Get field slips in XML format
```bash
curl "https://mushroomobserver.org/api2/field_slip?format=xml&detail=low"
```

### 12. Get field slips in JSON format (default)
```bash
curl "https://mushroomobserver.org/api2/field_slip?format=json&detail=low"
```

### 13. Get help on available parameters
```bash
curl "https://mushroomobserver.org/api2/field_slip?help=1"
```

### 14. Combine multiple filters (field slips from a project by a specific user)
```bash
curl "https://mushroomobserver.org/api2/field_slip?project=123&user=mary&detail=low"
```

## POST Requests (Create, Requires Authentication)

### 15. Create a new field slip with just a code
```bash
curl -X POST "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code=MYPROJ-0001"
```

### 16. Create a field slip with code and observation
```bash
curl -X POST "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code=NEMF-0042" \
  -d "observation=12345"
```

### 17. Create a field slip with code, observation, and project
```bash
curl -X POST "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code=EOL-9999" \
  -d "observation=12345" \
  -d "project=123"
```

### 18. Create a field slip and get detailed response
```bash
curl -X POST "https://mushroomobserver.org/api2/field_slip?detail=high" \
  -d "api_key=YOUR_API_KEY" \
  -d "code=TEST-0001" \
  -d "observation=12345"
```

## PATCH Requests (Update, Requires Authentication)

### 19. Update a field slip's code
```bash
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=456" \
  -d "set_code=UPDATED-0001"
```

### 20. Update a field slip's observation
```bash
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=456" \
  -d "set_observation=54321"
```

### 21. Update a field slip's project
```bash
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=456" \
  -d "set_project=789"
```

### 22. Update multiple attributes at once
```bash
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=456" \
  -d "set_code=NEWCODE-0001" \
  -d "set_observation=54321" \
  -d "set_project=789"
```

### 23. Update multiple field slips by code pattern
```bash
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code_has=EOL" \
  -d "set_project=123"
```

### 24. Clear a field slip's observation (set to null)
```bash
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=456" \
  -d "set_observation="
```

## DELETE Requests (Destroy, Requires Authentication)

### 25. Delete a field slip by ID
```bash
curl -X DELETE "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=456"
```

### 26. Delete field slips by code
```bash
curl -X DELETE "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code=TEMP-0001"
```

### 27. Delete field slips by code pattern
```bash
curl -X DELETE "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code_has=TEMP"
```

### 28. Delete field slips by observation
```bash
curl -X DELETE "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "observation=12345"
```

### 29. Delete your own field slips from a specific project
```bash
curl -X DELETE "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "user=YOUR_USERNAME" \
  -d "project=123"
```

## Notes

### Field Slip Code Format
- Codes are automatically converted to uppercase
- Codes must contain at least one non-digit, non-dash, non-period character
- Valid examples: `EOL-0001`, `NEMF-42`, `MYPROJECT-123`
- Invalid examples: `123`, `12-34`, `1.2.3` (only digits/dashes/periods)

### Permissions
- Anyone can read field slips (GET requests)
- Only authenticated users can create field slips (POST requests)
- Field slips can be edited by:
  - The user who created them
  - Project admins (if the field slip is in their project and they trust the creator)

### Pagination
- Low detail responses return up to 1000 results per page
- High detail responses return up to 100 results per page
- Use the `page` parameter to navigate: `?page=2`

### Error Handling
- Duplicate codes will return an error: "Field slip code 'XXX' is already in use."
- Missing required parameters will return appropriate error messages
- Permission errors will be returned if you try to edit someone else's field slip

### Testing Tips
1. Start with GET requests to explore existing data
2. Use `help=1` to see all available parameters
3. Test POST with a unique code first
4. Use the returned ID from POST to test PATCH and DELETE
5. Try invalid operations to see error messages
6. Check the `run_time` in responses and wait at least that long between requests

## Example Workflow

```bash
# 1. Get help on parameters
curl "https://mushroomobserver.org/api2/field_slip?help=1"

# 2. Query existing field slips
curl "https://mushroomobserver.org/api2/field_slip?detail=low"

# 3. Create a new field slip
curl -X POST "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "code=TEST-$(date +%s)"

# 4. Update the field slip (use the ID from step 3)
curl -X PATCH "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=RETURNED_ID" \
  -d "set_observation=12345"

# 5. Verify the update
curl "https://mushroomobserver.org/api2/field_slip?id=RETURNED_ID&detail=high"

# 6. Delete the test field slip
curl -X DELETE "https://mushroomobserver.org/api2/field_slip" \
  -d "api_key=YOUR_API_KEY" \
  -d "id=RETURNED_ID"
```
