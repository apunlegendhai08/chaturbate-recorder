-- Create table for storing GoFile upload records
CREATE TABLE IF NOT EXISTS gofile_uploads (
    id SERIAL PRIMARY KEY,
    streamer_name TEXT NOT NULL,
    gofile_link TEXT NOT NULL,
    upload_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on streamer_name for faster queries
CREATE INDEX IF NOT EXISTS idx_gofile_uploads_streamer_name ON gofile_uploads(streamer_name);

-- Create index on upload_date for time-based queries
CREATE INDEX IF NOT EXISTS idx_gofile_uploads_upload_date ON gofile_uploads(upload_date DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE gofile_uploads ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations (adjust based on your security needs)
CREATE POLICY "Allow all operations on gofile_uploads" ON gofile_uploads
    FOR ALL
    USING (true)
    WITH CHECK (true);
