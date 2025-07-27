module test

// With module declaration, only pub functions are runnable

pub fun main() {
  println("Public main function")
  testHelper()
}

pub fun testModule() {
  println("Testing module functionality")
}

fun testHelper() {
  // This private function should not show up in code lens
  println("Private test helper")
}

fun examplePrivate() {
  // This private example function should not show up in code lens  
  println("Private example")
}

pub fun examplePublic() {
  println("Public example function")
}