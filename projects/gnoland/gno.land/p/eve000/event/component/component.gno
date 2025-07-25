package component

import (
	"net/url"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/txlink"
)

// Interfaces

type EventSchedule interface {
	ToJson() string // schema.org compatible
	RenderMarkdown(body ...Content) string
	RenderCalendar(string) string
	Flyer() Component
}

type Page interface {
	ToJson() string // schema.org compatible
	RenderMarkdown(body ...Content) string
}

type Component interface {
	ToAnchor() string
	ToMarkdown(...Content) string
	ToJson() string // freeform JSON representation
	ToSVG() string
	ToSvgDataUrl() string
	RenderOpts() map[string]interface{}
}

// Types

// Event is a schema.org compatible status string
type EventStatus string

// EventAttendanceMode is a schema.org compatible attendance mode string
type EventAttendanceMode string

// Content is a user-editable content struct.
type Content struct {
	Published bool
	Markdown  string
	Callback  func(string) string
}

// Constants

const DtFmt = "Mon Jan 2"

const (
	EventScheduled   EventStatus = "https://schema.org/EventScheduled"
	EventCancelled   EventStatus = "https://schema.org/EventCancelled"
	EventMovedOnline EventStatus = "https://schema.org/EventMovedOnline"
	EventPostponed   EventStatus = "https://schema.org/EventPostponed"
	EventRescheduled EventStatus = "https://schema.org/EventRescheduled"
)

const (
	OfflineEventAttendanceMode EventAttendanceMode = "https://schema.org/OfflineEventAttendanceMode"
	OnlineEventAttendanceMode  EventAttendanceMode = "https://schema.org/OnlineEventAttendanceMode"
	MixedEventAttendanceMode   EventAttendanceMode = "https://schema.org/MixedEventAttendanceMode"
)

// Methods

func (c *Content) SetPublished(published bool) {
	c.Published = published
}

func (c *Content) SetMarkdown(markdown string) {
	c.Markdown = markdown
}

// Render displays stored content or calls the callback function if provided.
func (c *Content) Render(path ...string) string {
	if !c.Published || c.Markdown == "" && c.Callback == nil {
		return ""
	}
	if c.Callback != nil {
		if len(path) > 0 {
			return c.Callback(path[0])
		} else {
			return c.Callback("")
		}
	}
	return c.Markdown
}

// Functions

func RenderPage(path string, c Page, body ...Content) string {
	q := ParseQuery(path)
	format := q.Get("format")
	if format == "json" {
		var sb strings.Builder
		sb.WriteString("```\n\n" + c.ToJson() + "\n\n```")
		if len(body) > 0 {
			sb.WriteString("\n\n---\n\n")
		}
		for _, content := range body {
			if content.Published {
				sb.WriteString("\n\n" + content.Render() + "\n\n")
				sb.WriteString("---\n\n")
			}
		}
		return sb.String()
	}
	return c.RenderMarkdown(body...)
}

func RenderComponent(path string, c Component) (out string) {
	var sb strings.Builder

	if c == nil {
		return ""
	}

	u, err := url.Parse(path)
	if err != nil {
		panic("invalid path in RenderComponent: " + path)
	}

	switch u.Query().Get("format") {
	case "json":
		sb.WriteString("```json\n" + c.ToJson() + "\n```")
	case "frame": // show same view as frame
		sb.WriteString(c.ToJson())
	default:
		sb.WriteString(c.ToMarkdown())
	}

	if _, ok := c.RenderOpts()["Svg"]; ok {
		dataURL := c.ToSvgDataUrl()
		anchor := c.ToAnchor()
		sb.WriteString("\n[![" + anchor + "](" + dataURL + ")](" + anchor + ")\n\n---\n\n")
	}

	return sb.String()
}

func StringToAnchor(text string) string {
	text = strings.ToLower(text)
	text = strings.ReplaceAll(text, " ", "-")
	text = strings.ReplaceAll(text, ".", "")
	text = strings.ReplaceAll(text, ",", "")
	text = strings.ReplaceAll(text, ":", "")
	text = strings.ReplaceAll(text, ";", "")
	text = strings.ReplaceAll(text, "!", "")
	text = strings.ReplaceAll(text, "?", "")
	return "#" + text
}

func SplitText(text string, maxLength int) []string {
	var lines []string
	for len(text) > maxLength {
		splitAt := maxLength
		for splitAt > 0 && text[splitAt] != ' ' {
			splitAt--
		}
		if splitAt == 0 {
			splitAt = maxLength
		}
		lines = append(lines, text[:splitAt])
		text = text[splitAt:]
	}
	lines = append(lines, text)
	return lines
}

func SvgHeading(width, height string) string {
	svg := "<svg width=\"" + width + "\" height=\"" + height + "\" xmlns=\"http://www.w3.org/2000/svg\">"
	svg += "<style>"
	svg += ".title { font: bold 24px sans-serif; }"
	svg += ".subtitle { font: bold 18px sans-serif; }"
	svg += ".sessiontitle { font: bold 16px sans-serif; }"
	svg += ".text { font: 14px sans-serif; }"
	svg += ".label { font: bold 14px sans-serif; }"
	svg += ".speaker { font: 14px sans-serif; font-style: italic; }"
	svg += ".session { font: 14px sans-serif; margin-top: 20px; }"
	svg += "</style>"
	return svg
}

func RenderSVGLine(y *int, class, label, text string) string {
	var svg string
	if label != "" && text != "" {
		textLines := SplitText(text, 80)
		svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s"><tspan class="label">%s</tspan> %s</text>`, *y, class, label, textLines[0])
		*y += 20
		for _, line := range textLines[1:] {
			svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s">%s</text>`, *y, class, line)
			*y += 20
		}
	} else if text != "" {
		textLines := SplitText(text, 80)
		for _, line := range textLines {
			svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s">%s</text>`, *y, class, line)
			*y += 20
		}
	}
	return svg
}

func FormatDuration(duration time.Duration) string {
	d := strings.TrimRight(duration.String(), "0s")
	if strings.HasSuffix(d, "h0m") { // e.g., "1h0m0s"
		d = strings.TrimRight(d, "0m")
	}
	return d
}

func ParseDate(t string) time.Time {
	parsedTime, err := time.Parse(time.DateOnly, t)
	if err != nil {
		panic("DateOnly format required:" + time.DateOnly)
	}
	return parsedTime
}

func ParseTime(t string) time.Time {
	parsedTime, err := time.Parse(time.RFC3339, t)
	if err != nil {
		panic("RFC3339 format required:" + time.RFC3339)
	}
	return parsedTime
}

func ParseDuration(d string) time.Duration {
	parsedDuration, err := time.ParseDuration(d)
	if err != nil {
		panic("invalid duration format")
	}
	return parsedDuration
}

func TagString(tag string) string {
	tag = strings.ToLower(tag)
	tag = strings.ReplaceAll(tag, " ", "-")
	tag = strings.ReplaceAll(tag, ".", "")
	tag = strings.ReplaceAll(tag, ",", "")
	tag = strings.ReplaceAll(tag, ":", "")
	tag = strings.ReplaceAll(tag, ";", "")
	tag = strings.ReplaceAll(tag, "!", "")
	tag = strings.ReplaceAll(tag, "?", "")
	return tag
}

func LinkTag(name string) string {
	return "[" + name + "](?tag=" + TagString(name) + ")"
}

func ParseQuery(path string) url.Values {
	if len(path) > 0 && path[0] == '?' {
		u, err := url.Parse(std.CurrentRealm().PkgPath() + path)
		if err == nil {
			return u.Query()
		}
	}
	return url.Values{}
}

func escapeHtml(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&#39;")
	return s
}

func TxlinkButton(label, method string) string {
	return Button(label, txlink.NewLink(method).URL())
}

func Button(label, path string) string {
	return SubmitButton(label, path, 16, 120) // Default font size and min width
}

func SubmitButton(label, path string, fontSize, minWidth int) string {
	charWidth := int(0.6 * float64(fontSize)) // Approximate width of each character
	padding := 40                             // Total padding (left + right)
	h := 2 * fontSize                         // Height of the button, 2x font size for padding
	w := len(label)*charWidth + padding
	if w < minWidth {
		w = minWidth
	}

	svgButton := `<svg xmlns="http://www.w3.org/2000/svg" width="` + strconv.Itoa(w) + `" height="` + strconv.Itoa(h) + `">
<foreignObject x="16" y="-5" width="` + strconv.Itoa(w) + `" height="` + strconv.Itoa(h) + `">
  <body xmlns="http://www.w3.org/1999/xhtml">
    <button style="padding-left: 20px; font-size:` + strconv.Itoa(fontSize) + `px">
      ` + escapeHtml(label) + `
    </button>
  </body>
</foreignObject>
</svg>`

	dataUrl := "data:image/svg+xml;utf8," + url.PathEscape(svgButton)

	return "[![" + label + "](" + dataUrl + ")](" + path + ")"
}