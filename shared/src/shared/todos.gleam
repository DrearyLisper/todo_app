import gleam/dynamic/decode
import gleam/json

pub type TodoItem {
  TodoItem(label: String, done: Bool)
}

fn todo_item_decoder() -> decode.Decoder(TodoItem) {
  use label <- decode.field("label", decode.string)
  use done <- decode.field("done", decode.bool)
  decode.success(TodoItem(label:, done:))
}

pub fn todo_list_decoder() -> decode.Decoder(List(TodoItem)) {
  decode.list(todo_item_decoder())
}

fn todo_item_to_json(todo_item: TodoItem) -> json.Json {
  let TodoItem(label:, done:) = todo_item
  json.object([#("label", json.string(label)), #("done", json.bool(done))])
}

pub fn todo_list_to_json(items: List(TodoItem)) -> json.Json {
  json.array(items, todo_item_to_json)
}
