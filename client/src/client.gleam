import gleam/http/response.{type Response}
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
  let styles = [
    #("max-width", "40ch"),
    #("margin", "0 auto"),
    #("display", "flex"),
    #("flex-direction", "column"),
    #("gap", "1em"),
  ]

  html.div([attribute.styles(styles)], [
    html.h1([], [html.text("TODO")]),
    view_todo_list(model.items),
    view_new_item(model.new_item),
    case model.saving {
      True -> html.p([], [html.text("Saving...")])
      False -> element.none()
    },
    case model.error {
      option.None -> element.none()
      option.Some(error) ->
        html.div([attribute.style("color", "red")], [html.text(error)])
    },
  ])
}

fn view_new_item(new_item: String) -> Element(Message) {
  html.div([attribute.styles([#("display", "flex"), #("gap", "0.5em")])], [
    html.input([
      attribute.placeholder("Enter a new todo"),
      attribute.value(new_item),
      event.on_input(UserTypedNewItem),
    ]),
    html.button([event.on_click(UserAddedItem)], [html.text("Add")]),
  ])
}

fn view_todo_list(items: List(TodoItem)) -> Element(Message) {
  case items {
    [] -> html.p([], [html.text("No todos yet. Add one above!")])
    _ -> {
      html.ul(
        [],
        list.index_map(items, fn(item, index) {
          html.li([], [view_todo_item(item, index)])
        }),
      )
    }
  }
}

fn view_todo_item(item: TodoItem, index: Int) -> Element(Message) {
  html.div(
    [
      attribute.styles([
        #("display", "flex"),
        #("align-items", "center"),
        #("gap", "0.5em"),
      ]),
    ],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(item.done),
        event.on_check(fn(_checked) { UserToggledItem(index) }),
      ]),
      html.span(
        [
          attribute.styles([
            #("flex", "1"),
            #("text-decoration", case item.done {
              True -> "line-through"
              False -> "none"
            }),
          ]),
        ],
        [html.text(item.label)],
      ),
      html.button([event.on_click(UserDeletedItem(index))], [
        html.text("Delete"),
      ]),
    ],
  )
}
