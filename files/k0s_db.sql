
-- table to store k0s tokens

CREATE TABLE IF NOT EXISTS k0s_tokens (
    id SERIAL PRIMARY KEY,
    cluster TEXT NOT NULL,
    origin TEXT NOT NULL,
    role TEXT NOT NULL,
    token TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- table to store k0s CA certs - at the moment all clusters rely on the same CA cert

CREATE TABLE IF NOT EXISTS k0s_certs (
    id SERIAL PRIMARY KEY,
    cluster TEXT NOT NULL UNIQUE,  -- Ensure uniqueness
    certs TEXT NOT NULL,           -- Store the Base64 certs as TEXT
    created_at TIMESTAMP DEFAULT NOW()
);

-- Relevant queries /  tasks

-- k0s token create --role=controller | psql -h your-db-host -U your-db-user -d k0s -c "INSERT INTO k0s_tokens (role, token) VALUES ('controller', '$(cat -)');"

-- TOKEN=$(psql -h your-db-host -U your-db-user -d k0s -t -A -c "SELECT token FROM k0s_tokens WHERE role='controller' ORDER BY created_at DESC LIMIT 1;")

-- DELETE FROM k0s_tokens WHERE created_at < NOW() - INTERVAL '1 day';
