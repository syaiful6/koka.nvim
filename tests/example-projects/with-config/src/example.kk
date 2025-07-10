import std/core

fun greet(name: string): string
  "Hello, " ++ name ++ "!"

fun main()
  println(greet("World"))