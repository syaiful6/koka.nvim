// Example Koka file with runnable functions

fun main() {
  println("Hello, Koka!")
  testBasic()
  exampleUsage()
}

fun testBasic() {
  println("Running basic test...")
  val result = 1 + 1
  if result == 2 then
    println("✓ Test passed")
  else
    println("✗ Test failed")
}

fun testAdvanced() {
  println("Running advanced test...")
  val result = fibonacci(5)
  if result == 5 then
    println("✓ Advanced test passed")
  else
    println("✗ Advanced test failed")
}

fun exampleUsage() {
  println("Example: Computing fibonacci numbers")
  [1,2,3,4,5].foreach(fn(n) {
    println("fib(" ++ n.show ++ ") = " ++ fibonacci(n).show)
  })
}

fun fibonacci(n: int): <div|e> int {
  if n <= 1 then n else fibonacci(n - 1) + fibonacci(n - 2)
}

fun helper() {
  // This function should not show up in code lens
  ()
}