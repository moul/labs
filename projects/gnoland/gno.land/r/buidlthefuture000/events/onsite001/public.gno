package onsite

func RenderCalendar(path string) string {
	return app.LiveEvent().RenderCalendar(path)
}

func Render(path string) (out string) {
	return app.Render(path) + "\n\n" + registry.GetPatchLevel() + "\n\n"
}
