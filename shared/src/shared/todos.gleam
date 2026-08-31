import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/string

pub type TodoItem {
  TodoItem(id: String, label: String, done: Bool, due: String)
}

fn todo_item_decoder() -> decode.Decoder(TodoItem) {
  use id <- decode.optional_field("id", "", decode.string)
  use label <- decode.field("label", decode.string)
  use done <- decode.field("done", decode.bool)
  use due <- decode.optional_field("due", "", decode.string)
  decode.success(TodoItem(id:, label:, done:, due:))
}

pub fn todo_list_decoder() -> decode.Decoder(List(TodoItem)) {
  decode.list(todo_item_decoder())
}

fn todo_item_to_json(todo_item: TodoItem) -> json.Json {
  let TodoItem(id:, label:, done:, due:) = todo_item
  json.object([
    #("id", json.string(id)),
    #("label", json.string(label)),
    #("done", json.bool(done)),
    #("due", json.string(due)),
  ])
}

pub fn todo_list_to_json(items: List(TodoItem)) -> json.Json {
  json.array(items, todo_item_to_json)
}

// ORDERING & GROUPING ---------------------------------------------------------

pub fn sort_by_due(items: List(TodoItem)) -> List(TodoItem) {
  list.sort(items, fn(a, b) { string.compare(a.due, b.due) })
}

pub fn group_by_due(items: List(TodoItem)) -> List(#(String, List(TodoItem))) {
  case items {
    [] -> []
    [first, ..rest] -> {
      let reversed =
        list.fold(rest, [#(first.due, [first])], fn(groups, item) {
          case groups {
            [#(group_due, rows), ..later] if group_due == item.due ->
              list.prepend(later, #(group_due, list.prepend(rows, item)))
            _ -> list.prepend(groups, #(item.due, [item]))
          }
        })

      reversed
      |> list.reverse()
      |> list.map(fn(group) {
        let #(due, rows) = group
        #(due, list.reverse(rows))
      })
    }
  }
}

// DUE DATE LABELS -------------------------------------------------------------

pub fn due_label(due: String, today: String) -> String {
  case due == today, due == next_day(today) {
    True, _ -> "Today"
    _, True -> "Tomorrow"
    False, False -> format_date(due, today)
  }
}

fn parse_iso(iso: String) -> Result(#(Int, Int, Int), Nil) {
  case string.split(iso, "-") {
    [year, month, day] ->
      case int.parse(year), int.parse(month), int.parse(day) {
        Ok(y), Ok(m), Ok(d) -> Ok(#(y, m, d))
        _, _, _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn next_day(iso: String) -> String {
  case parse_iso(iso) {
    Error(Nil) -> iso
    Ok(#(year, month, day)) ->
      case day >= days_in_month(year, month) {
        True ->
          case month >= 12 {
            True -> format_iso(year + 1, 1, 1)
            False -> format_iso(year, month + 1, 1)
          }
        False -> format_iso(year, month, day + 1)
      }
  }
}

fn days_in_month(year: Int, month: Int) -> Int {
  case month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
    4 | 6 | 9 | 11 -> 30
    2 ->
      case year % 4 == 0 && { year % 100 != 0 || year % 400 == 0 } {
        True -> 29
        False -> 28
      }
    _ -> 30
  }
}

fn format_iso(year: Int, month: Int, day: Int) -> String {
  int.to_string(year) <> "-" <> pad_two(month) <> "-" <> pad_two(day)
}

fn pad_two(value: Int) -> String {
  case value < 10 {
    True -> "0" <> int.to_string(value)
    False -> int.to_string(value)
  }
}

fn format_date(due: String, today: String) -> String {
  case parse_iso(due), parse_iso(today) {
    Ok(#(year, month, day)), Ok(#(today_year, _, _)) -> {
      let base = month_name(month) <> " " <> int.to_string(day)
      case year == today_year {
        True -> base
        False -> base <> ", " <> int.to_string(year)
      }
    }
    _, _ -> due
  }
}

fn month_name(month: Int) -> String {
  case month {
    1 -> "Jan"
    2 -> "Feb"
    3 -> "Mar"
    4 -> "Apr"
    5 -> "May"
    6 -> "Jun"
    7 -> "Jul"
    8 -> "Aug"
    9 -> "Sep"
    10 -> "Oct"
    11 -> "Nov"
    12 -> "Dec"
    _ -> "?"
  }
}
