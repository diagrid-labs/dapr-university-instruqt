COUNT=$(docker exec dapr_postgres psql -U postgres -d venuedb -tAc "SELECT count(*) FROM bookings;" 2>/dev/null)

if [ -z "$COUNT" ] || [ "$COUNT" -eq 0 ] 2>/dev/null; then
    fail-message "No rows found in the bookings table yet. Run the app and POST to /bookings first."
else
    echo "Found $COUNT booking(s) in Postgres! 👍"
fi
