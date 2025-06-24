-- Create default admin user
-- Password: guacadmin (will be hashed by Guacamole)

INSERT INTO guacamole_user (username, password_hash, password_salt, password_date)
VALUES (
    'guacadmin',
    decode('CA458A7D494E3BE824F5E1E175A1556C0F8EEF2C2D7DF3633BEC4A29C4411960', 'hex'),
    decode('FE24ADC5E11E2B25288D1704ABE67A79E342ECC26064CE69C5B3177795A82264', 'hex'),
    CURRENT_TIMESTAMP
) ON CONFLICT (username) DO NOTHING;

-- Grant admin permissions
INSERT INTO guacamole_user_permission (user_id, permission)
SELECT user_id, 'ADMINISTER'
FROM guacamole_user
WHERE username = 'guacadmin'
ON CONFLICT DO NOTHING;
