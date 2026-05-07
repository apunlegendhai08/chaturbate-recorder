package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// This script fixes thumbnail URLs in the database by converting Pixhost show URLs
// to direct image URLs. Run this once to fix existing records.

func main() {
	log.Println("╔════════════════════════════════════════════════════════════╗")
	log.Println("║     🔧 Fixing Thumbnail URLs in Database                  ║")
	log.Println("╚════════════════════════════════════════════════════════════╝")
	log.Println("")

	databaseDir := "database"
	if _, err := os.Stat(databaseDir); os.IsNotExist(err) {
		log.Println("❌ Database directory does not exist")
		return
	}

	totalFixed := 0
	totalFiles := 0

	// Walk through all recordings.json files
	err := filepath.Walk(databaseDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}

		if info.IsDir() || filepath.Base(path) != "recordings.json" {
			return nil
		}

		totalFiles++
		log.Printf("📁 Processing: %s", path)

		// Read the JSON file
		data, err := os.ReadFile(path)
		if err != nil {
			log.Printf("   ❌ Failed to read: %v", err)
			return nil
		}

		var dbData map[string]interface{}
		if err := json.Unmarshal(data, &dbData); err != nil {
			log.Printf("   ❌ Failed to parse JSON: %v", err)
			return nil
		}

		recordings, ok := dbData["recordings"].([]interface{})
		if !ok {
			log.Printf("   ⚠️  No recordings array found")
			return nil
		}

		modified := false
		fixedInFile := 0

		// Fix each recording's thumbnail URL
		for _, rec := range recordings {
			recMap, ok := rec.(map[string]interface{})
			if !ok {
				continue
			}

			thumbnailLink, ok := recMap["thumbnail_link"].(string)
			if !ok || thumbnailLink == "" {
				continue
			}

			// Check if it's a Pixhost show URL that needs fixing
			if strings.Contains(thumbnailLink, "pixhost.to/show/") {
				fixedURL := convertPixhostShowURLToDirectURL(thumbnailLink)
				if fixedURL != thumbnailLink {
					recMap["thumbnail_link"] = fixedURL
					modified = true
					fixedInFile++
					log.Printf("   ✓ Fixed: %s", filepath.Base(thumbnailLink))
				}
			}
		}

		if modified {
			// Write back to file
			jsonData, err := json.MarshalIndent(dbData, "", "  ")
			if err != nil {
				log.Printf("   ❌ Failed to marshal JSON: %v", err)
				return nil
			}

			if err := os.WriteFile(path, jsonData, 0644); err != nil {
				log.Printf("   ❌ Failed to write file: %v", err)
				return nil
			}

			log.Printf("   ✅ Updated %d thumbnail(s) in this file", fixedInFile)
			totalFixed += fixedInFile
		} else {
			log.Printf("   ℹ️  No thumbnails needed fixing")
		}

		return nil
	})

	if err != nil {
		log.Printf("❌ Error walking database: %v", err)
	}

	log.Println("")
	log.Println("╔════════════════════════════════════════════════════════════╗")
	log.Println("║                    Migration Complete                      ║")
	log.Println("╚════════════════════════════════════════════════════════════╝")
	log.Printf("📊 Files processed: %d", totalFiles)
	log.Printf("✅ Thumbnails fixed: %d", totalFixed)
	log.Println("")
}

// convertPixhostShowURLToDirectURL converts a Pixhost show URL to a direct image URL
// Example: https://pixhost.to/show/272/223818418_filename.jpg
//       -> https://img75.pixhost.to/images/272/223818418_filename.jpg
func convertPixhostShowURLToDirectURL(showURL string) string {
	// Pattern: https://pixhost.to/show/{server}/{id}_{filename}
	re := regexp.MustCompile(`https://pixhost\.to/show/(\d+)/(\d+_.+)`)
	matches := re.FindStringSubmatch(showURL)

	if len(matches) != 3 {
		// Not a valid Pixhost show URL, return as-is
		return showURL
	}

	serverNum := matches[1]
	imageFile := matches[2]

	// Pixhost uses img servers numbered from img1 to img100+
	// We'll use a simple mapping based on server number
	imgServer := fmt.Sprintf("img%s", serverNum)

	// Construct direct image URL
	directURL := fmt.Sprintf("https://%s.pixhost.to/images/%s/%s", imgServer, serverNum, imageFile)

	return directURL
}
