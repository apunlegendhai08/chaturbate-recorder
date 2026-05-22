package uploader

import (
	"fmt"
	"log"
	"runtime"
	"sync"
)

// Logger is the interface for logging upload events.
// The channel package implements this with ch.Info/ch.Error.
type Logger interface {
	Info(format string, a ...any)
	Error(format string, a ...any)
}

// UploadResult contains the result of an upload to a specific host
type UploadResult struct {
	Host         string
	DownloadLink string
	Error        error
}

// MultiHostUploader handles uploading to multiple hosts simultaneously
type MultiHostUploader struct {
	gofile      *GoFileUploader
	turboviplay *TurboViPlayUploader
	voesx       *VoeSXUploader
	sendcm      *SendCMUploader
	byse        *ByseUploader
	log         Logger
}

// NewMultiHostUploader creates a new multi-host uploader
func NewMultiHostUploader(turboViPlayAPIKey, voeSXAPIKey, sendCMAPIKey, byseAPIKey string, log Logger) *MultiHostUploader {
	if log == nil {
		log = &nilLogger{}
	}
	return &MultiHostUploader{
		gofile:      NewGoFileUploader(),
		turboviplay: NewTurboViPlayUploader(turboViPlayAPIKey),
		voesx:       NewVoeSXUploader(voeSXAPIKey),
		sendcm:      NewSendCMUploader(sendCMAPIKey),
		byse:        NewByseUploader(byseAPIKey),
		log:         log,
	}
}

const defaultUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

// nilLogger discards all log messages when no logger is provided.
type nilLogger struct{}

func (n *nilLogger) Info(format string, a ...any) {}
func (n *nilLogger) Error(format string, a ...any) {}

// uploadSem limits the number of concurrent uploads to prevent OOM during
// recovery (e.g. many orphaned files uploading at startup simultaneously).
var uploadSem = make(chan struct{}, 3)

// recoverUpload catches a panic inside an upload goroutine, logs it with a
// stack trace, and stores it as an error in the result set.
func recoverUpload(host string, resultsMu *sync.Mutex, results *[]UploadResult) {
	if r := recover(); r != nil {
		buf := make([]byte, 8192)
		n := runtime.Stack(buf, false)
		log.Printf("PANIC [upload/%s]: %v\n%s", host, r, buf[:n])
		resultsMu.Lock()
		*results = append(*results, UploadResult{
			Host:  host,
			Error: fmt.Errorf("upload panic: %v", r),
		})
		resultsMu.Unlock()
	}
}

// UploadToAll uploads a file to all configured hosts in parallel.
// At most 3 uploads run concurrently (uploadSem) to cap memory usage.
// A panic inside any individual upload is caught, logged, and returned as
// an error — it never crashes the calling goroutine or the whole process.
func (m *MultiHostUploader) UploadToAll(filePath string) []UploadResult {
	var wg sync.WaitGroup
	results := []UploadResult{}
	resultsMu := sync.Mutex{}

	// Upload to GoFile
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer recoverUpload("GoFile", &resultsMu, &results)
		uploadSem <- struct{}{}
		defer func() { <-uploadSem }()
		m.log.Info("upload: starting GoFile upload for %s", filePath)
		link, err := m.gofile.Upload(filePath)
		resultsMu.Lock()
		results = append(results, UploadResult{Host: "GoFile", DownloadLink: link, Error: err})
		resultsMu.Unlock()
		if err != nil {
			m.log.Error("upload: GoFile failed for %s: %v", filePath, err)
		} else {
			m.log.Info("upload: GoFile successful for %s: %s", filePath, link)
		}
	}()

	// Upload to TurboViPlay (only if API key is configured)
	if m.turboviplay != nil && m.turboviplay.apiKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer recoverUpload("TurboViPlay", &resultsMu, &results)
			uploadSem <- struct{}{}
			defer func() { <-uploadSem }()
			m.log.Info("upload: starting TurboViPlay upload for %s", filePath)
			link, err := m.turboviplay.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{Host: "TurboViPlay", DownloadLink: link, Error: err})
			resultsMu.Unlock()
			if err != nil {
				m.log.Error("upload: TurboViPlay failed for %s: %v", filePath, err)
			} else {
				m.log.Info("upload: TurboViPlay successful for %s: %s", filePath, link)
			}
		}()
	}

	// Upload to VOE.sx (only if API key is configured)
	if m.voesx != nil && m.voesx.apiKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer recoverUpload("VOE.sx", &resultsMu, &results)
			uploadSem <- struct{}{}
			defer func() { <-uploadSem }()
			m.log.Info("upload: starting VOE.sx upload for %s", filePath)
			link, err := m.voesx.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{Host: "VOE.sx", DownloadLink: link, Error: err})
			resultsMu.Unlock()
			if err != nil {
				m.log.Error("upload: VOE.sx failed for %s: %v", filePath, err)
			} else {
				m.log.Info("upload: VOE.sx successful for %s: %s", filePath, link)
			}
		}()
	}

	// Upload to SendCM (always, guest upload if no API key)
	if m.sendcm != nil {
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer recoverUpload("SendCM", &resultsMu, &results)
			uploadSem <- struct{}{}
			defer func() { <-uploadSem }()
			m.log.Info("upload: starting SendCM upload for %s", filePath)
			link, err := m.sendcm.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{Host: "SendCM", DownloadLink: link, Error: err})
			resultsMu.Unlock()
			if err != nil {
				m.log.Error("upload: SendCM failed for %s: %v", filePath, err)
			} else {
				m.log.Info("upload: SendCM successful for %s: %s", filePath, link)
			}
		}()
	}

	// Upload to Byse (only if API key is configured)
	if m.byse != nil && m.byse.apiKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer recoverUpload("Byse", &resultsMu, &results)
			uploadSem <- struct{}{}
			defer func() { <-uploadSem }()
			m.log.Info("upload: starting Byse upload for %s", filePath)
			link, err := m.byse.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{Host: "Byse", DownloadLink: link, Error: err})
			resultsMu.Unlock()
			if err != nil {
				m.log.Error("upload: Byse failed for %s: %v", filePath, err)
			} else {
				m.log.Info("upload: Byse successful for %s: %s", filePath, link)
			}
		}()
	}

	// Wait for all uploads to complete
	wg.Wait()

	return results
}

// GetSuccessfulUploads returns only the successful upload results
func GetSuccessfulUploads(results []UploadResult) []UploadResult {
	var successful []UploadResult
	for _, result := range results {
		if result.Error == nil && result.DownloadLink != "" {
			successful = append(successful, result)
		}
	}
	return successful
}

// FormatResults formats upload results into a readable string
func FormatResults(results []UploadResult) string {
	var output string
	successCount := 0

	for _, result := range results {
		if result.Error == nil && result.DownloadLink != "" {
			output += fmt.Sprintf("✓ %s: %s\n", result.Host, result.DownloadLink)
			successCount++
		} else {
			output += fmt.Sprintf("✗ %s: %v\n", result.Host, result.Error)
		}
	}

	output = fmt.Sprintf("Upload completed: %d/%d successful\n%s", successCount, len(results), output)
	return output
}
