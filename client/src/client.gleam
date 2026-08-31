import gleam/dynamic/decode
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import plinth/browser/document
import plinth/browser/element as dom
import rsvp
import shared/todos.{type TodoItem, TodoItem}

@external(javascript, "./client_ffi.mjs", "today_iso")
fn today_iso() -> String {
  ""
}

@external(javascript, "./client_ffi.mjs", "new_id")
fn new_id() -> String {
  ""
}

pub fn main() -> Nil {
  let initial_items =
    document.query_selector("#model")
    |> result.map(dom.inner_text)
    |> result.try(fn(text) {
      json.parse(text, todos.todo_list_decoder())
      |> result.replace_error(Nil)
    })
    |> result.unwrap([])

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", initial_items)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(
    items: List(TodoItem),
    new_item: String,
    saving: Bool,
    error: Option(String),
    dragging: Option(Int),
    dragged: Bool,
    today: String,
    editing_date: Option(String),
  )
}

fn init(items: List(TodoItem)) -> #(Model, Effect(Message)) {
  let today = today_iso()
  let items =
    items
    |> list.map(fn(item) {
      let id = case item.id == "" {
        True -> new_id()
        False -> item.id
      }
      let due = case item.due == "" {
        True -> today
        False -> item.due
      }
      TodoItem(..item, id:, due:)
    })

  let model =
    Model(
      items: todos.sort_by_due(items),
      new_item: "",
      saving: False,
      error: option.None,
      dragging: option.None,
      dragged: False,
      today:,
      editing_date: option.None,
    )

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Message {
  ServerSaved(Result(Response(String), rsvp.Error(String)))
  UserAddedItem
  UserDeletedItem(index: Int)
  UserToggledItem(index: Int)
  UserTypedNewItem(String)
  UserDragStarted(index: Int)
  UserDragOver(index: Int)
  UserDragEnded
  UserDateEditStarted(id: String)
  UserDateChanged(id: String, value: String)
  UserDateEditEnded
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ServerSaved(Ok(_)) -> #(
      Model(..model, saving: False, error: option.None),
      effect.none(),
    )

    ServerSaved(Error(_)) -> #(
      Model(..model, saving: False, error: option.Some("Failed to save list")),
      effect.none(),
    )

    UserTypedNewItem(text) -> #(Model(..model, new_item: text), effect.none())

    UserAddedItem ->
      case model.new_item {
        "" -> #(model, effect.none())
        label ->
          Model(
            ..model,
            items: model.items
              |> list.append([
                TodoItem(
                  id: new_id(),
                  label: label,
                  done: False,
                  due: model.today,
                ),
              ])
              |> todos.sort_by_due(),
            new_item: "",
          )
          |> save
      }

    UserToggledItem(index) ->
      Model(
        ..model,
        items: list.index_map(model.items, fn(item, item_index) {
          case item_index == index {
            True -> TodoItem(..item, done: !item.done)
            False -> item
          }
        }),
      )
      |> save

    UserDeletedItem(index) ->
      Model(
        ..model,
        items: model.items
          |> list.index_map(fn(item, item_index) {
            case item_index == index {
              True -> []
              False -> [item]
            }
          })
          |> list.flatten(),
      )
      |> save

    UserDragStarted(index) -> #(
      Model(..model, dragging: option.Some(index), dragged: False),
      effect.none(),
    )

    UserDragOver(index) ->
      case model.dragging {
        option.None -> #(model, effect.none())
        option.Some(from) ->
          case item_at(model.items, from), item_at(model.items, index) {
            Ok(moved), Ok(target) ->
              case moved.due == target.due {
                True -> #(
                  Model(
                    ..model,
                    items: move_item(model.items, from, index),
                    dragging: option.Some(index),
                    dragged: True,
                  ),
                  effect.none(),
                )
                False -> {
                  let updated =
                    model.items
                    |> list.map(fn(item) {
                      case item.id == moved.id {
                        True -> TodoItem(..item, due: target.due)
                        False -> item
                      }
                    })
                    |> todos.sort_by_due()

                  let new_from = case index_of_id(updated, moved.id) {
                    found if found >= 0 -> found
                    _ -> index
                  }

                  #(
                    Model(
                      ..model,
                      items: updated,
                      dragging: option.Some(new_from),
                      dragged: True,
                    ),
                    effect.none(),
                  )
                }
              }
            _, _ -> #(model, effect.none())
          }
      }

    UserDragEnded ->
      case model.dragging, model.dragged {
        option.Some(_), True -> Model(..model, dragging: option.None) |> save
        option.Some(_), False -> #(
          Model(..model, dragging: option.None),
          effect.none(),
        )
        option.None, _ -> #(model, effect.none())
      }

    UserDateEditStarted(id) -> #(
      Model(..model, editing_date: option.Some(id)),
      effect.none(),
    )

    UserDateChanged(id, value) ->
      case value {
        "" -> #(Model(..model, editing_date: option.None), effect.none())
        _ ->
          Model(
            ..model,
            items: model.items
              |> list.map(fn(item) {
                case item.id == id {
                  True -> TodoItem(..item, due: value)
                  False -> item
                }
              })
              |> todos.sort_by_due(),
            editing_date: option.None,
          )
          |> save
      }

    UserDateEditEnded -> #(
      Model(..model, editing_date: option.None),
      effect.none(),
    )
  }
}

fn item_at(items: List(TodoItem), index: Int) -> Result(TodoItem, Nil) {
  case index >= 0 {
    True ->
      items
      |> list.drop(index)
      |> list.first()
    False -> Error(Nil)
  }
}

fn index_of_id(items: List(TodoItem), id: String) -> Int {
  list.index_fold(items, -1, fn(found, item, index) {
    case found >= 0 {
      True -> found
      False ->
        case item.id == id {
          True -> index
          False -> found
        }
    }
  })
}

fn move_item(items: List(TodoItem), from: Int, to: Int) -> List(TodoItem) {
  case from == to, items {
    True, _ -> items
    False, [] -> items
    False, _ -> {
      let #(before, middle) = list.split(items, from)
      case middle {
        [] -> items
        [moved, ..rest] -> {
          let without = list.append(before, rest)
          let #(head, tail) = list.split(without, to)
          head
          |> list.append([moved])
          |> list.append(tail)
        }
      }
    }
  }
}

fn save(model: Model) -> #(Model, Effect(Message)) {
  #(Model(..model, saving: True), save_list(model.items))
}

fn save_list(items: List(TodoItem)) -> Effect(Message) {
  rsvp.post(
    "/api/todos",
    todos.todo_list_to_json(items),
    rsvp.expect_ok_response(ServerSaved),
  )
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Message) {
  html.div([attribute.class("app")], [
    html.header([attribute.class("app-header")], [
      html.h1([], [html.text("TODO")]),
      case list.is_empty(model.items) {
        True -> element.none()
        False ->
          html.span([attribute.class("count")], [
            html.text(int.to_string(remaining(model.items)) <> " left"),
          ])
      },
    ]),
    view_new_item(model.new_item),
    view_todo_list(model),
    case model.saving {
      True -> html.p([attribute.class("status")], [html.text("Saving...")])
      False -> element.none()
    },
    case model.error {
      option.None -> element.none()
      option.Some(error) ->
        html.p([attribute.class("error")], [html.text(error)])
    },
  ])
}

fn remaining(items: List(TodoItem)) -> Int {
  items
  |> list.filter(fn(item) { !item.done })
  |> list.length()
}

fn view_new_item(new_item: String) -> Element(Message) {
  html.div([attribute.class("add-row")], [
    html.input([
      attribute.type_("text"),
      attribute.placeholder("Add a new task..."),
      attribute.value(new_item),
      attribute.autofocus(True),
      event.on_input(UserTypedNewItem),
    ]),
    html.button(
      [
        attribute.class("btn btn-add"),
        attribute.type_("button"),
        event.on_click(UserAddedItem),
      ],
      [html.text("Add")],
    ),
  ])
}

fn group_with_index(
  items: List(TodoItem),
) -> List(#(String, List(#(TodoItem, Int)))) {
  let built =
    list.index_fold(items, [], fn(groups, item, index) {
      case groups {
        [] -> [#(item.due, [#(item, index)])]
        [#(due, rows), ..later] if due == item.due ->
          list.prepend(later, #(due, list.prepend(rows, #(item, index))))
        _ -> list.prepend(groups, #(item.due, [#(item, index)]))
      }
    })

  built
  |> list.reverse()
  |> list.map(fn(group) {
    let #(due, rows) = group
    #(due, list.reverse(rows))
  })
}

fn view_todo_list(model: Model) -> Element(Message) {
  case model.items {
    [] ->
      html.p([attribute.class("empty-state")], [
        html.text("Nothing here yet. Add your first task above!"),
      ])
    _ -> {
      let list_class =
        "todo-list"
        <> case model.dragging {
          option.Some(_) -> " dragging-list"
          option.None -> ""
        }

      html.div(
        [attribute.class("todo-groups")],
        model.items
          |> group_with_index()
          |> list.map(fn(group) {
            let #(due, rows) = group
            html.section([attribute.class("todo-group")], [
              html.h2([attribute.class("group-header")], [
                html.text(todos.due_label(due, model.today)),
              ]),
              html.ul(
                [attribute.class(list_class)],
                list.map(rows, fn(row) {
                  let #(item, index) = row
                  view_todo_item(item, index, model)
                }),
              ),
            ])
          }),
      )
    }
  }
}

fn view_due(item: TodoItem, model: Model) -> Element(Message) {
  case model.editing_date {
    option.Some(editing_id) if editing_id == item.id ->
      html.input([
        attribute.type_("date"),
        attribute.class("due-input"),
        attribute.value(item.due),
        attribute.autofocus(True),
        event.on_change(fn(value) { UserDateChanged(item.id, value) }),
        event.on("blur", decode.success(UserDateEditEnded)),
      ])
    _ ->
      html.button(
        [
          attribute.class("due-button"),
          attribute.type_("button"),
          attribute.title("Change due date"),
          event.on_click(UserDateEditStarted(item.id)),
        ],
        [html.text(todos.due_label(item.due, model.today))],
      )
  }
}

fn view_todo_item(
  item: TodoItem,
  index: Int,
  model: Model,
) -> Element(Message) {
  let is_dragging = case model.dragging {
    option.Some(i) -> i == index
    option.None -> False
  }
  let class =
    {
      case item.done {
        True -> "todo-item done"
        False -> "todo-item"
      }
    }
    <> case is_dragging {
      True -> " dragging"
      False -> ""
    }

  html.li(
    [
      attribute.class(class),
      attribute.draggable(True),
      attribute.title("Drag onto another date group to change its due date"),
      event.on("dragstart", decode.success(UserDragStarted(index))),
      event.prevent_default(event.on(
        "dragover",
        decode.success(UserDragOver(index)),
      )),
      event.on("dragend", decode.success(UserDragEnded)),
    ],
    [
      html.span(
        [
          attribute.class("drag-handle"),
          attribute.aria_hidden(True),
        ],
        [],
      ),
      html.label([attribute.class("todo-check")], [
        html.input([
          attribute.type_("checkbox"),
          attribute.checked(item.done),
          event.on_check(fn(_checked) { UserToggledItem(index) }),
        ]),
        html.span([attribute.class("todo-label")], [html.text(item.label)]),
      ]),
      view_due(item, model),
      html.button(
        [
          attribute.class("btn-delete"),
          attribute.type_("button"),
          attribute.title("Delete task"),
          event.on_click(UserDeletedItem(index)),
        ],
        [html.text("✕")],
      ),
    ],
  )
}
