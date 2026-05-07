-- Fix Pixhost thumbnail URLs by converting show URLs to direct image URLs
-- This migration updates existing records that have Pixhost show URLs

-- Update video_uploads table
UPDATE video_uploads
SET thumbnail_link = REGEXP_REPLACE(
    thumbnail_link,
    'https://pixhost\.to/show/(\d+)/(\d+_.+)',
    'https://img\1.pixhost.to/images/\1/\2',
    'g'
)
WHERE thumbnail_link LIKE '%pixhost.to/show/%';

-- Show how many records were updated
SELECT 
    'video_uploads' as table_name,
    COUNT(*) as records_with_pixhost_thumbnails
FROM video_uploads
WHERE thumbnail_link LIKE '%pixhost.to/images/%';
