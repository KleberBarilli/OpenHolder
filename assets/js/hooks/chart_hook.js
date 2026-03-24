export const ChartHook = {
  async mounted() {
    const {Chart, registerables} = await import("chart.js")
    Chart.register(...registerables)
    Chart.defaults.color = "#94a3b8"
    Chart.defaults.borderColor = "#222233"

    const config = JSON.parse(this.el.dataset.config)
    this.chart = new Chart(this.el, config)
  },
  async updated() {
    if (!this.chart) return
    const config = JSON.parse(this.el.dataset.config)
    this.chart.data = config.data
    if (config.options) this.chart.options = config.options
    this.chart.update()
  },
  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}
