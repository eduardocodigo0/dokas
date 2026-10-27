import dokas/domain
import dokas/ffi
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event

/// The state of the whole application.
pub type Model {
  Model(
    menu: List(domain.MenuItem),
    cart: List(domain.CartItem),
    customer_name: String,
    notes: String,
    order_type: Option(domain.OrderType),
    delivery_address: String,
    payment_method: Option(domain.PaymentMethod),
    cash_note: String,
    active_category: domain.Category,
    error: Option(domain.Error),
  )
}

/// Every way the outside world can communicate with the application.
pub type Msg {
  SelectCategory(domain.Category)
  Increment(Int, Int)
  Decrement(Int, Int)
  Remove(Int, Int)
  UpdateName(String)
  UpdateNotes(String)
  SelectOrderType(domain.OrderType)
  UpdateAddress(String)
  SelectPaymentMethod(domain.PaymentMethod)
  UpdateCashNote(String)
  DismissError
  CartLoaded(String)
}

/// Builds the Lustre application.
pub fn application() -> lustre.App(Nil, Model, Msg) {
  lustre.application(init, update, view)
}

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      menu: domain.menu(),
      cart: [],
      customer_name: "",
      notes: "",
      order_type: None,
      delivery_address: "",
      payment_method: None,
      cash_note: "",
      active_category: domain.Lanches,
      error: None,
    )
  #(model, load_cart())
}

fn load_cart() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    dispatch(CartLoaded(ffi.local_storage_get(domain.storage_key)))
  })
}

fn persist_cart(cart: List(domain.CartItem)) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    ffi.local_storage_set(domain.storage_key, domain.cart_to_storage(cart))
  })
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SelectCategory(category) -> #(
      Model(..model, active_category: category, error: None),
      effect.none(),
    )
    Increment(item_id, variation_index) ->
      case domain.increment(model.cart, item_id, variation_index) {
        Ok(cart) -> #(
          Model(..model, cart: cart, error: None),
          persist_cart(cart),
        )
        Error(error) -> #(Model(..model, error: Some(error)), effect.none())
      }
    Decrement(item_id, variation_index) -> {
      let cart = domain.decrement(model.cart, item_id, variation_index)
      #(Model(..model, cart: cart, error: None), persist_cart(cart))
    }
    Remove(item_id, variation_index) -> {
      let cart = domain.remove(model.cart, item_id, variation_index)
      #(Model(..model, cart: cart, error: None), persist_cart(cart))
    }
    UpdateName(value) -> #(
      Model(..model, customer_name: domain.clean_name(value)),
      effect.none(),
    )
    UpdateNotes(value) -> #(
      Model(..model, notes: domain.clean_notes(value)),
      effect.none(),
    )
    SelectOrderType(order_type) -> #(
      Model(..model, order_type: Some(order_type), error: None),
      effect.none(),
    )
    UpdateAddress(value) -> #(
      Model(..model, delivery_address: domain.clean_address(value)),
      effect.none(),
    )
    SelectPaymentMethod(payment_method) -> #(
      Model(..model, payment_method: Some(payment_method), error: None),
      effect.none(),
    )
    UpdateCashNote(value) -> #(
      Model(..model, cash_note: domain.clean_cash_note(value)),
      effect.none(),
    )
    DismissError -> #(Model(..model, error: None), effect.none())
    CartLoaded(stored) -> {
      let cart = domain.cart_from_storage(stored, model.menu)
      #(Model(..model, cart: cart), effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("min-h-screen bg-orange-50 text-zinc-900")], [
    header_view(),
    html.main(
      [attribute.class("mx-auto w-full max-w-6xl px-4 pb-16 pt-6 sm:px-6")],
      [
        error_view(model.error),
        html.div([attribute.class("grid gap-6 lg:grid-cols-[1fr_360px]")], [
          html.div([attribute.class("space-y-5")], [
            category_tabs_view(model.active_category),
            menu_view(model),
          ]),
          summary_view(model),
        ]),
      ],
    ),
    footer_view(),
  ])
}

fn header_view() -> Element(Msg) {
  html.header(
    [
      attribute.class(
        "bg-gradient-to-r from-orange-600 via-orange-500 to-amber-500 shadow-lg",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "mx-auto flex w-full max-w-6xl flex-col gap-1 px-4 py-7 sm:px-6",
          ),
        ],
        [
          html.h1(
            [
              attribute.class(
                "text-2xl font-extrabold tracking-tight text-white sm:text-3xl",
              ),
            ],
            [text("Doka's Lanches")],
          ),
          html.p([attribute.class("text-sm font-medium text-orange-50")], [
            text("Monte seu pedido e envie direto pelo WhatsApp"),
          ]),
        ],
      ),
    ],
  )
}

fn category_tabs_view(active: domain.Category) -> Element(Msg) {
  html.div(
    [attribute.class("flex gap-2 overflow-x-auto pb-1")],
    list.map(domain.categories(), fn(category) {
      html.button(
        [
          attribute.class(tab_class(category == active)),
          attribute.type_("button"),
          event.on_click(SelectCategory(category)),
        ],
        [text(domain.category_label(category))],
      )
    }),
  )
}

fn tab_class(is_active: Bool) -> String {
  case is_active {
    True ->
      "shrink-0 rounded-full bg-orange-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-orange-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-orange-400"
    False ->
      "shrink-0 rounded-full bg-white px-4 py-2 text-sm font-semibold text-zinc-700 ring-1 ring-orange-200 transition hover:bg-orange-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-orange-400"
  }
}

fn menu_view(model: Model) -> Element(Msg) {
  html.div(
    [attribute.class("grid gap-3 sm:grid-cols-2")],
    list.map(
      domain.items_for_category(model.menu, model.active_category),
      fn(item) { menu_item_view(item, model.cart) },
    ),
  )
}

fn menu_item_view(
  item: domain.MenuItem,
  cart: List(domain.CartItem),
) -> Element(Msg) {
  html.article(
    [
      attribute.class(
        "flex flex-col gap-3 rounded-2xl bg-white p-4 shadow-sm ring-1 ring-orange-100",
      ),
    ],
    [
      html.div([], [
        html.h3(
          [attribute.class("text-base font-bold leading-tight text-zinc-900")],
          [text(item.name)],
        ),
        description_view(item.description),
      ]),
      html.div(
        [attribute.class("mt-auto space-y-2")],
        list.index_map(item.variations, fn(variation, index) {
          variation_view(item, variation, index, cart)
        }),
      ),
    ],
  )
}

fn description_view(description: String) -> Element(Msg) {
  case description {
    "" -> html.div([], [])
    content ->
      html.p([attribute.class("mt-1 text-xs leading-snug text-zinc-500")], [
        text(content),
      ])
  }
}

fn variation_view(
  item: domain.MenuItem,
  variation: domain.Variation,
  index: Int,
  cart: List(domain.CartItem),
) -> Element(Msg) {
  let quantity = domain.item_quantity(cart, item.id, index)
  html.div(
    [
      attribute.class(
        "flex items-center justify-between gap-2 rounded-xl bg-orange-50 px-3 py-2",
      ),
    ],
    [
      html.div(
        [attribute.class("flex min-w-0 flex-col")],
        list.append(label_view(variation.label), [
          html.span([attribute.class("text-sm font-bold text-zinc-900")], [
            text(domain.format_price(variation.price)),
          ]),
        ]),
      ),
      quantity_view(item.id, index, quantity),
    ],
  )
}

fn label_view(label: String) -> List(Element(Msg)) {
  case label {
    "" -> []
    label -> [
      html.span(
        [
          attribute.class(
            "text-[11px] font-semibold uppercase tracking-wide text-orange-700",
          ),
        ],
        [text(label)],
      ),
    ]
  }
}

fn quantity_view(
  item_id: Int,
  variation_index: Int,
  quantity: Int,
) -> Element(Msg) {
  html.div([attribute.class("flex items-center gap-1")], [
    html.button(
      [
        attribute.class(
          "flex h-8 w-8 items-center justify-center rounded-full bg-white text-lg font-bold text-orange-700 ring-1 ring-orange-200 transition hover:bg-orange-100 disabled:cursor-not-allowed disabled:opacity-40",
        ),
        attribute.type_("button"),
        attribute.disabled(quantity == 0),
        event.on_click(Decrement(item_id, variation_index)),
      ],
      [text("-")],
    ),
    html.span(
      [attribute.class("w-8 text-center text-sm font-bold text-zinc-900")],
      [text(int.to_string(quantity))],
    ),
    html.button(
      [
        attribute.class(
          "flex h-8 w-8 items-center justify-center rounded-full bg-orange-600 text-lg font-bold text-white shadow-sm transition hover:bg-orange-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-orange-400",
        ),
        attribute.type_("button"),
        event.on_click(Increment(item_id, variation_index)),
      ],
      [text("+")],
    ),
  ])
}

fn summary_view(model: Model) -> Element(Msg) {
  html.aside(
    [
      attribute.class(
        "h-fit rounded-2xl bg-white p-5 shadow-sm ring-1 ring-orange-100 lg:sticky lg:top-6",
      ),
    ],
    [
      html.div([attribute.class("flex items-center justify-between")], [
        html.h2([attribute.class("text-lg font-extrabold text-zinc-900")], [
          text("Seu pedido"),
        ]),
        item_count_badge(model.cart),
      ]),
      case model.cart {
        [] -> empty_cart_view()
        _ -> filled_cart_view(model)
      },
      order_options_view(model),
      customer_form_view(model),
      checkout_view(model),
    ],
  )
}

fn item_count_badge(cart: List(domain.CartItem)) -> Element(Msg) {
  html.span(
    [
      attribute.class(
        "rounded-full bg-orange-100 px-2.5 py-1 text-xs font-bold text-orange-700",
      ),
    ],
    [text(int.to_string(domain.total_quantity(cart)) <> " itens")],
  )
}

fn empty_cart_view() -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "mt-3 rounded-xl border border-dashed border-orange-200 bg-orange-50 px-4 py-6 text-center",
      ),
    ],
    [
      html.p([attribute.class("text-sm font-medium text-zinc-500")], [
        text("Seu carrinho está vazio."),
      ]),
      html.p([attribute.class("mt-1 text-xs text-zinc-400")], [
        text("Escolha itens no cardápio para começar."),
      ]),
    ],
  )
}

fn filled_cart_view(model: Model) -> Element(Msg) {
  html.div([attribute.class("mt-3")], [
    html.ul(
      [attribute.class("divide-y divide-orange-100")],
      list.map(model.cart, fn(cart_item) {
        cart_line_view(cart_item, model.menu)
      }),
    ),
    html.div(
      [
        attribute.class(
          "mt-2 flex items-center justify-between border-t border-orange-100 pt-3",
        ),
      ],
      [
        html.span([attribute.class("text-sm font-semibold text-zinc-500")], [
          text("Total"),
        ]),
        html.span([attribute.class("text-xl font-extrabold text-orange-700")], [
          text(domain.format_price(domain.total_price(model.cart, model.menu))),
        ]),
      ],
    ),
  ])
}

fn cart_line_view(
  cart_item: domain.CartItem,
  menu: List(domain.MenuItem),
) -> Element(Msg) {
  case
    domain.item_and_variation(
      menu,
      cart_item.item_id,
      cart_item.variation_index,
    )
  {
    Ok(#(item, variation)) -> {
      let label = case variation.label {
        "" -> item.name
        label -> item.name <> " (" <> label <> ")"
      }
      html.li([attribute.class("flex items-start justify-between gap-2 py-2")], [
        html.div([attribute.class("min-w-0")], [
          html.p(
            [attribute.class("truncate text-sm font-semibold text-zinc-800")],
            [text(label)],
          ),
          html.p([attribute.class("text-xs text-zinc-500")], [
            text(
              int.to_string(cart_item.quantity)
              <> " × "
              <> domain.format_price(variation.price)
              <> " = "
              <> domain.format_price(variation.price * cart_item.quantity),
            ),
          ]),
        ]),
        html.button(
          [
            attribute.class(
              "shrink-0 rounded-full p-1 text-zinc-400 transition hover:bg-red-50 hover:text-red-600",
            ),
            attribute.type_("button"),
            event.on_click(Remove(cart_item.item_id, cart_item.variation_index)),
          ],
          [text("✕")],
        ),
      ])
    }
    Error(_) -> html.li([], [])
  }
}

fn order_options_view(model: Model) -> Element(Msg) {
  html.div([attribute.class("mt-4 space-y-4")], [
    html.div([], [
      html.p([attribute.class(field_label_class())], [text("Tipo de pedido *")]),
      html.div([attribute.class("mt-1 grid grid-cols-2 gap-2")], [
        order_type_button(domain.Retirada, model.order_type),
        order_type_button(domain.Entrega, model.order_type),
      ]),
    ]),
    address_view(model),
    html.div([], [
      html.p([attribute.class(field_label_class())], [
        text("Forma de pagamento *"),
      ]),
      html.div([attribute.class("mt-1 grid grid-cols-2 gap-2")], [
        payment_button(domain.Pix, model.payment_method),
        payment_button(domain.CartaoDebito, model.payment_method),
        payment_button(domain.CartaoCredito, model.payment_method),
        payment_button(domain.Dinheiro, model.payment_method),
      ]),
    ]),
    cash_note_view(model),
  ])
}

fn field_label_class() -> String {
  "mb-1 block text-[11px] font-semibold uppercase tracking-wide text-zinc-500"
}

fn input_class() -> String {
  "w-full rounded-xl bg-orange-50 px-3 py-2 text-sm text-zinc-900 ring-1 ring-orange-200 placeholder:text-zinc-400 focus:outline-none focus:ring-2 focus:ring-orange-500"
}

fn option_button_class(is_active: Bool) -> String {
  case is_active {
    True ->
      "rounded-xl bg-orange-600 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-orange-700"
    False ->
      "rounded-xl bg-orange-50 px-3 py-2 text-sm font-semibold text-zinc-700 ring-1 ring-orange-200 transition hover:bg-orange-100"
  }
}

fn order_type_button(
  order_type: domain.OrderType,
  selected: Option(domain.OrderType),
) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(option_button_class(selected == Some(order_type))),
      event.on_click(SelectOrderType(order_type)),
    ],
    [text(domain.order_type_label(order_type))],
  )
}

fn payment_button(
  payment_method: domain.PaymentMethod,
  selected: Option(domain.PaymentMethod),
) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(option_button_class(selected == Some(payment_method))),
      event.on_click(SelectPaymentMethod(payment_method)),
    ],
    [text(domain.payment_method_label(payment_method))],
  )
}

fn address_view(model: Model) -> Element(Msg) {
  case model.order_type {
    Some(domain.Entrega) ->
      html.div([], [
        html.label(
          [
            attribute.class(field_label_class()),
            attribute.for("delivery-address"),
          ],
          [text("Endereço de entrega *")],
        ),
        html.input([
          attribute.type_("text"),
          attribute.id("delivery-address"),
          attribute.name("delivery-address"),
          attribute.value(model.delivery_address),
          attribute.placeholder("Rua, número, bairro, referência..."),
          attribute.maxlength(160),
          attribute.autocomplete("street-address"),
          attribute.class(input_class()),
          event.on_input(UpdateAddress),
        ]),
      ])
    _ -> html.div([], [])
  }
}

fn cash_note_view(model: Model) -> Element(Msg) {
  case model.payment_method {
    Some(domain.Dinheiro) ->
      html.div([], [
        html.label(
          [attribute.class(field_label_class()), attribute.for("cash-note")],
          [text("Nota para troco *")],
        ),
        html.input([
          attribute.type_("text"),
          attribute.id("cash-note"),
          attribute.name("cash-note"),
          attribute.value(model.cash_note),
          attribute.placeholder("Ex.: R$ 50,00"),
          attribute.maxlength(30),
          attribute.class(input_class()),
          event.on_input(UpdateCashNote),
        ]),
      ])
    _ -> html.div([], [])
  }
}

fn customer_form_view(model: Model) -> Element(Msg) {
  html.div([attribute.class("mt-4 space-y-3")], [
    html.div([], [
      html.label(
        [
          attribute.class(
            "mb-1 block text-[11px] font-semibold uppercase tracking-wide text-zinc-500",
          ),
          attribute.for("customer-name"),
        ],
        [text("Seu nome")],
      ),
      html.input([
        attribute.type_("text"),
        attribute.id("customer-name"),
        attribute.name("customer-name"),
        attribute.value(model.customer_name),
        attribute.placeholder("Ex.: Maria"),
        attribute.maxlength(80),
        attribute.autocomplete("name"),
        attribute.class(
          "w-full rounded-xl bg-orange-50 px-3 py-2 text-sm text-zinc-900 ring-1 ring-orange-200 placeholder:text-zinc-400 focus:outline-none focus:ring-2 focus:ring-orange-500",
        ),
        event.on_input(UpdateName),
      ]),
    ]),
    html.div([], [
      html.label(
        [
          attribute.class(
            "mb-1 block text-[11px] font-semibold uppercase tracking-wide text-zinc-500",
          ),
          attribute.for("notes"),
        ],
        [text("Observações")],
      ),
      html.textarea(
        [
          attribute.id("notes"),
          attribute.name("notes"),
          attribute.rows(3),
          attribute.maxlength(500),
          attribute.placeholder("Ex.: sem cebola, ponto da carne..."),
          attribute.class(
            "w-full resize-none rounded-xl bg-orange-50 px-3 py-2 text-sm text-zinc-900 ring-1 ring-orange-200 placeholder:text-zinc-400 focus:outline-none focus:ring-2 focus:ring-orange-500",
          ),
          event.on_input(UpdateNotes),
        ],
        model.notes,
      ),
    ]),
  ])
}

fn checkout_view(model: Model) -> Element(Msg) {
  case domain.total_quantity(model.cart) == 0 {
    True -> checkout_disabled("Adicione pelo menos um item ao pedido")
    False ->
      case checkout_is_complete(model) {
        True ->
          html.a(
            [
              attribute.class(
                "mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-green-600 px-4 py-3 text-sm font-bold text-white shadow-sm transition hover:bg-green-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-green-400",
              ),
              attribute.href(domain.whatsapp_url(
                model.cart,
                model.menu,
                model.customer_name,
                model.notes,
                checkout_info(model),
              )),
              attribute.target("_blank"),
              attribute.rel("noopener noreferrer"),
            ],
            [text("Finalizar pedido no WhatsApp")],
          )
        False -> checkout_disabled(checkout_missing_message(model))
      }
  }
}

fn checkout_is_complete(model: Model) -> Bool {
  domain.is_checkout_complete(
    model.order_type,
    model.delivery_address,
    model.payment_method,
    model.cash_note,
  )
}

fn checkout_info(model: Model) -> domain.CheckoutInfo {
  domain.CheckoutInfo(
    order_type: case model.order_type {
      Some(order_type) -> order_type
      None -> domain.Retirada
    },
    delivery_address: model.delivery_address,
    payment_method: case model.payment_method {
      Some(payment_method) -> payment_method
      None -> domain.Pix
    },
    cash_note: model.cash_note,
  )
}

fn checkout_missing_message(model: Model) -> String {
  let missing =
    domain.missing_checkout_fields(
      model.order_type,
      model.delivery_address,
      model.payment_method,
      model.cash_note,
    )
  "Complete: "
  <> string.join(list.map(missing, domain.checkout_field_label), ", ")
}

fn checkout_disabled(message: String) -> Element(Msg) {
  html.div([attribute.class("mt-4 space-y-2")], [
    html.button(
      [
        attribute.class(
          "w-full cursor-not-allowed rounded-xl bg-zinc-200 px-4 py-3 text-sm font-bold text-zinc-500",
        ),
        attribute.type_("button"),
        attribute.disabled(True),
      ],
      [text("Finalizar pedido no WhatsApp")],
    ),
    html.p(
      [
        attribute.class("text-center text-xs font-semibold text-red-600"),
        attribute.role("alert"),
      ],
      [text(message)],
    ),
  ])
}

fn error_view(error: Option(domain.Error)) -> Element(Msg) {
  case error {
    None -> html.div([], [])
    Some(error) ->
      html.div(
        [
          attribute.class(
            "mb-4 flex items-start justify-between gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-red-800",
          ),
          attribute.role("alert"),
        ],
        [
          html.p([attribute.class("text-sm font-semibold")], [
            text(domain.error_message(error)),
          ]),
          html.button(
            [
              attribute.class(
                "shrink-0 rounded-full px-2 text-lg leading-none text-red-500 transition hover:text-red-700",
              ),
              attribute.type_("button"),
              event.on_click(DismissError),
            ],
            [text("✕")],
          ),
        ],
      )
  }
}

fn footer_view() -> Element(Msg) {
  html.footer(
    [
      attribute.class(
        "border-t border-orange-100 bg-white/70 py-6 text-center text-xs text-zinc-500",
      ),
    ],
    [
      html.p([], [
        text("Doka's Lanches — cardápio digital feito com Gleam + Lustre"),
      ]),
    ],
  )
}
