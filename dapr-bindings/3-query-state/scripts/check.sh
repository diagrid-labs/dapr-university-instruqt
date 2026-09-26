COUNT=$(docker exec dapr_postgres psql -U postgres -d venuedb -tAc "SELECT count(*) FROM bookings;" 2>/dev/null)

if [ -z "$COUNT" ] || [ "$COUNT" -lt 2 ] 2>/dev/null; then
    fail-message "Expected at least 2 bookings in Postgres. Save one more with a POST, then query again."
else
    echo "Found $COUNT bookings, queried through the same binding! 👍"
fi
