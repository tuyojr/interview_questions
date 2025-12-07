#!/bin/bash
set -e

DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

sudo yum update -y
sudo amazon-linux-extras install -y postgresql14
sudo yum install -y postgresql-server postgresql-contrib


sudo postgresql-setup --initdb

cat > /var/lib/pgsql/data/postgresql.conf << EOF
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 128MB
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
EOF

cat > /var/lib/pgsql/data/pg_hba.conf << EOF
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all             all             10.0.0.0/16             md5
EOF

sudo chown postgres:postgres /var/lib/pgsql/data/postgresql.conf
sudo chown postgres:postgres /var/lib/pgsql/data/pg_hba.conf

sudo systemctl enable postgresql
sudo systemctl start postgresql
sleep 5

if [[ -n "$DB_PASSWORD" ]]; then
    sudo -u postgres psql << EOSQL
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOSQL
fi

echo "PostgreSQL setup completed at $(date)" >> /var/log/user-data.log
echo "Connection: psql -h $PRIVATE_IP -U $DB_USER -d $DB_NAME"
