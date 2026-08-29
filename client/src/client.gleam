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
  )
}

fn init(items: List(TodoItem)) -> #(Model, Effect(Message)) {
  let model =
    Model(items: items, new_item: "", saving: False, error: option.None)

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Message {
  ServerSaved(Result(Response(String), rsvp.Error(String)))
  UserAddedItem
  UserDeletedItem(index: Int)
  UserToggledItem(index: Int)
  UserTypedNewItem(String)
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
            items: list.append(model.items, [TodoItem(label:, done: False)]),
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
    view_todo_list(model.items),
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

fn view_todo_list(items: List(TodoItem)) -> Element(Message) {
  case items {
    [] ->
      html.p([attribute.class("empty-state")], [
        html.text("Nothing here yet. Add your first task above!"),
      ])
    _ -> {
      html.ul(
        [attribute.class("todo-list")],
        list.index_map(items, fn(item, index) { view_todo_item(item, index) }),
      )
    }
  }
}

fn view_todo_item(item: TodoItem, index: Int) -> Element(Message) {
  html.li(
    [
      attribute.class(case item.done {
        True -> "todo-item done"
        False -> "todo-item"
      }),
    ],
    [
      html.label([attribute.class("todo-check")], [
        html.input([
          attribute.type_("checkbox"),
          attribute.checked(item.done),
          event.on_check(fn(_checked) { UserToggledItem(index) }),
        ]),
        html.span([attribute.class("todo-label")], [html.text(item.label)]),
      ]),
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
