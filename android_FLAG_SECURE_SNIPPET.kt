// Put this in your Android MainActivity class.
// Example package/class structure depends on your Flutter project.

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    window.setFlags(
        android.view.WindowManager.LayoutParams.FLAG_SECURE,
        android.view.WindowManager.LayoutParams.FLAG_SECURE
    )
}
