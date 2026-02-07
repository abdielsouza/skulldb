#!/bin/bash
# Install SkullDB Swagger UI Dependencies
# Run this script to fetch the new dependencies for Swagger UI support

echo "Installing Swagger UI dependencies for SkullDB..."
echo ""

# Update mix.lock and install dependencies
mix deps.get

echo ""
echo "✓ Dependencies installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Start the server: mix run --no-halt"
echo "  2. Open your browser to: http://localhost:4000/api/docs"
echo "  3. See SWAGGER.md for more details"
echo ""
