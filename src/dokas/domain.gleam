import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

/// Maximum quantity allowed for a single item variation.
pub const max_per_item = 20

/// Maximum quantity allowed for the whole cart.
pub const max_total = 50

/// WhatsApp number used to receive orders.
pub const whatsapp_number = "5518991115722"

/// Key used to persist the cart in the browser's localStorage.
pub const storage_key = "dokas_cart"

/// Menu categories shown as tabs in the interface.
pub type Category {
  Lanches
  Refrigerantes
  BebidasLata
  Sucos
}

/// A purchasable variation of a menu item (size/label + price in cents).
pub type Variation {
  Variation(label: String, price: Int)
}

/// An item available in the menu. Prices are stored in cents to avoid
/// floating point rounding errors.
pub type MenuItem {
  MenuItem(
    id: Int,
    name: String,
    description: String,
    category: Category,
    variations: List(Variation),
  )
}

/// A selected item in the cart. The item is identified by its menu id and the
/// index of the chosen variation.
pub type CartItem {
  CartItem(item_id: Int, variation_index: Int, quantity: Int)
}

/// Validation and error states surfaced to the interface.
pub type Error {
  CartEmpty
  ItemLimitReached
  CartLimitReached
  InvalidData
}

/// How the customer wants to receive the order.
pub type OrderType {
  Retirada
  Entrega
}

/// How the customer wants to pay for the order.
pub type PaymentMethod {
  Pix
  CartaoDebito
  CartaoCredito
  Dinheiro
}

/// The checkout details included in the WhatsApp message.
pub type CheckoutInfo {
  CheckoutInfo(
    order_type: OrderType,
    delivery_address: String,
    payment_method: PaymentMethod,
    cash_note: String,
  )
}

/// A required checkout field that has not been filled in yet.
pub type CheckoutField {
  OrderTypeMissing
  AddressMissing
  PaymentMissing
  CashNoteMissing
}

// CATEGORIES ------------------------------------------------------------------

pub fn categories() -> List(Category) {
  [Lanches, Refrigerantes, BebidasLata, Sucos]
}

pub fn category_label(category: Category) -> String {
  case category {
    Lanches -> "Lanches"
    Refrigerantes -> "Refrigerantes"
    BebidasLata -> "Bebidas em Lata"
    Sucos -> "Sucos"
  }
}

pub fn items_for_category(
  menu: List(MenuItem),
  category: Category,
) -> List(MenuItem) {
  list.filter(menu, fn(item) { item.category == category })
}

// MONEY -----------------------------------------------------------------------

/// Formats a price in cents as a Brazilian Real string, e.g. 2300 -> "R$ 23,00".
pub fn format_price(cents: Int) -> String {
  let reais = cents / 100
  let centavos = cents % 100
  "R$ "
  <> int.to_string(reais)
  <> ","
  <> string.pad_start(int.to_string(centavos), 2, "0")
}

// CART QUERIES ----------------------------------------------------------------

pub fn item_and_variation(
  menu: List(MenuItem),
  item_id: Int,
  variation_index: Int,
) -> Result(#(MenuItem, Variation), Nil) {
  case list.find(menu, fn(item) { item.id == item_id }) {
    Ok(item) ->
      case list.first(list.drop(item.variations, variation_index)) {
        Ok(variation) -> Ok(#(item, variation))
        Error(_) -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

pub fn item_quantity(
  cart: List(CartItem),
  item_id: Int,
  variation_index: Int,
) -> Int {
  case
    list.find(cart, fn(cart_item) {
      cart_item.item_id == item_id
      && cart_item.variation_index == variation_index
    })
  {
    Ok(cart_item) -> cart_item.quantity
    Error(_) -> 0
  }
}

pub fn total_quantity(cart: List(CartItem)) -> Int {
  list.fold(cart, 0, fn(total, cart_item) { total + cart_item.quantity })
}

pub fn line_total(cart_item: CartItem, menu: List(MenuItem)) -> Int {
  case item_and_variation(menu, cart_item.item_id, cart_item.variation_index) {
    Ok(#(_, variation)) -> variation.price * cart_item.quantity
    Error(_) -> 0
  }
}

pub fn total_price(cart: List(CartItem), menu: List(MenuItem)) -> Int {
  list.fold(cart, 0, fn(total, cart_item) {
    total + line_total(cart_item, menu)
  })
}

// CART MUTATIONS --------------------------------------------------------------

/// Increments the quantity of a cart item, enforcing the per-item and global
/// limits. Returns an `Error` (and leaves the cart untouched) when a limit is
/// reached.
pub fn increment(
  cart: List(CartItem),
  item_id: Int,
  variation_index: Int,
) -> Result(List(CartItem), Error) {
  let current = item_quantity(cart, item_id, variation_index)
  case current >= max_per_item {
    True -> Error(ItemLimitReached)
    False ->
      case total_quantity(cart) >= max_total {
        True -> Error(CartLimitReached)
        False -> Ok(increment_cart(cart, item_id, variation_index))
      }
  }
}

fn increment_cart(
  cart: List(CartItem),
  item_id: Int,
  variation_index: Int,
) -> List(CartItem) {
  case
    list.find(cart, fn(cart_item) {
      cart_item.item_id == item_id
      && cart_item.variation_index == variation_index
    })
  {
    Ok(_) ->
      list.map(cart, fn(cart_item) {
        case
          cart_item.item_id == item_id
          && cart_item.variation_index == variation_index
        {
          True ->
            CartItem(
              cart_item.item_id,
              cart_item.variation_index,
              cart_item.quantity + 1,
            )
          False -> cart_item
        }
      })
    Error(_) -> list.append(cart, [CartItem(item_id, variation_index, 1)])
  }
}

/// Decrements the quantity of a cart item, removing it when it reaches zero.
pub fn decrement(
  cart: List(CartItem),
  item_id: Int,
  variation_index: Int,
) -> List(CartItem) {
  list.filter_map(cart, fn(cart_item) {
    case
      cart_item.item_id == item_id
      && cart_item.variation_index == variation_index
    {
      True ->
        case cart_item.quantity > 1 {
          True ->
            Ok(CartItem(
              cart_item.item_id,
              cart_item.variation_index,
              cart_item.quantity - 1,
            ))
          False -> Error(Nil)
        }
      False -> Ok(cart_item)
    }
  })
}

/// Removes an item from the cart entirely.
pub fn remove(
  cart: List(CartItem),
  item_id: Int,
  variation_index: Int,
) -> List(CartItem) {
  list.filter(cart, fn(cart_item) {
    cart_item.item_id != item_id || cart_item.variation_index != variation_index
  })
}

// ERROR MESSAGES --------------------------------------------------------------

pub fn error_message(error: Error) -> String {
  case error {
    CartEmpty -> "Adicione pelo menos um item ao pedido."
    ItemLimitReached ->
      "Limite de "
      <> int.to_string(max_per_item)
      <> " unidades por item atingido."
    CartLimitReached ->
      "Limite de " <> int.to_string(max_total) <> " itens no carrinho atingido."
    InvalidData -> "Não foi possível recuperar o carrinho salvo."
  }
}

// CHECKOUT --------------------------------------------------------------------

pub fn order_type_label(order_type: OrderType) -> String {
  case order_type {
    Retirada -> "Retirada no estabelecimento"
    Entrega -> "Entrega"
  }
}

pub fn payment_method_label(method: PaymentMethod) -> String {
  case method {
    Pix -> "Pix"
    CartaoDebito -> "Cartão de débito"
    CartaoCredito -> "Cartão de crédito"
    Dinheiro -> "Dinheiro"
  }
}

pub fn checkout_field_label(field: CheckoutField) -> String {
  case field {
    OrderTypeMissing -> "tipo de pedido"
    AddressMissing -> "endereço de entrega"
    PaymentMissing -> "forma de pagamento"
    CashNoteMissing -> "nota para troco"
  }
}

/// Returns the list of required checkout fields that are still missing.
pub fn missing_checkout_fields(
  order_type: Option(OrderType),
  delivery_address: String,
  payment_method: Option(PaymentMethod),
  cash_note: String,
) -> List(CheckoutField) {
  let order_fields = case order_type {
    None -> [OrderTypeMissing]
    Some(Entrega) ->
      case string.trim(delivery_address) {
        "" -> [AddressMissing]
        _ -> []
      }
    Some(Retirada) -> []
  }

  let payment_fields = case payment_method {
    None -> [PaymentMissing]
    Some(Dinheiro) ->
      case string.trim(cash_note) {
        "" -> [CashNoteMissing]
        _ -> []
      }
    Some(_) -> []
  }

  list.append(order_fields, payment_fields)
}

pub fn is_checkout_complete(
  order_type: Option(OrderType),
  delivery_address: String,
  payment_method: Option(PaymentMethod),
  cash_note: String,
) -> Bool {
  list.is_empty(missing_checkout_fields(
    order_type,
    delivery_address,
    payment_method,
    cash_note,
  ))
}

// INPUT SANITISATION ----------------------------------------------------------

/// Cleans a customer name: removes control characters and caps its length.
/// Keeps whitespace intact so the user can type naturally while editing.
pub fn clean_name(input: String) -> String {
  clean_input(input, 80, False)
}

/// Cleans free-text notes: keeps newlines/tabs but removes other control
/// characters and caps the length.
pub fn clean_notes(input: String) -> String {
  clean_input(input, 500, True)
}

/// Cleans a delivery address: keeps newlines/tabs and caps its length.
pub fn clean_address(input: String) -> String {
  clean_input(input, 160, True)
}

/// Cleans the cash amount used to prepare change.
pub fn clean_cash_note(input: String) -> String {
  clean_input(input, 30, False)
}

fn clean_input(input: String, max_length: Int, allow_newline: Bool) -> String {
  input
  |> string.to_utf_codepoints
  |> list.filter(fn(codepoint) {
    is_allowed_codepoint(string.utf_codepoint_to_int(codepoint), allow_newline)
  })
  |> string.from_utf_codepoints
  |> string.slice(0, max_length)
}

fn is_allowed_codepoint(codepoint: Int, allow_newline: Bool) -> Bool {
  case codepoint {
    10 -> allow_newline
    9 -> allow_newline
    _ -> codepoint >= 32 && codepoint != 127
  }
}

// PERSISTENCE -----------------------------------------------------------------

/// Serialises the cart into a compact string suitable for localStorage.
/// Format: "item_id:variation_index:quantity;..." (internal, non-public data).
pub fn cart_to_storage(cart: List(CartItem)) -> String {
  cart
  |> list.map(fn(cart_item) {
    int.to_string(cart_item.item_id)
    <> ":"
    <> int.to_string(cart_item.variation_index)
    <> ":"
    <> int.to_string(cart_item.quantity)
  })
  |> string.join(";")
}

/// Restores a cart from storage, discarding malformed entries and clamping
/// quantities against the menu and the configured limits.
pub fn cart_from_storage(
  input: String,
  menu: List(MenuItem),
) -> List(CartItem) {
  input
  |> string.split(";")
  |> list.filter_map(parse_cart_item)
  |> validate_cart(menu)
  |> cap_total
}

fn parse_cart_item(chunk: String) -> Result(CartItem, Nil) {
  case string.split(chunk, ":") {
    [item_id, variation_index, quantity] ->
      case int.parse(item_id), int.parse(variation_index), int.parse(quantity) {
        Ok(item_id), Ok(variation_index), Ok(quantity) ->
          Ok(CartItem(item_id, variation_index, quantity))
        _, _, _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn validate_cart(cart: List(CartItem), menu: List(MenuItem)) -> List(CartItem) {
  list.filter(cart, fn(cart_item) {
    let valid_item =
      result.is_ok(item_and_variation(
        menu,
        cart_item.item_id,
        cart_item.variation_index,
      ))
    cart_item.quantity > 0 && cart_item.quantity <= max_per_item && valid_item
  })
}

fn cap_total(cart: List(CartItem)) -> List(CartItem) {
  let #(_, capped) =
    list.fold(cart, #(0, []), fn(acc, cart_item) {
      let #(used, kept) = acc
      let remaining = max_total - used
      case remaining <= 0 {
        True -> acc
        False -> {
          let quantity = case cart_item.quantity > remaining {
            True -> remaining
            False -> cart_item.quantity
          }
          #(
            used + quantity,
            list.append(kept, [
              CartItem(cart_item.item_id, cart_item.variation_index, quantity),
            ]),
          )
        }
      }
    })
  capped
}

// WHATSAPP --------------------------------------------------------------------

/// Percent-encodes a value to be safely embedded in a URL. This is equivalent
/// (and stricter) to JavaScript's `encodeURIComponent`: newlines become `%0A`,
/// spaces `%20`, accents are UTF-8 encoded and `&`, `?` and `#` are escaped.
pub fn encode_uri_component(value: String) -> String {
  uri.percent_encode(value)
}

pub fn whatsapp_url(
  cart: List(CartItem),
  menu: List(MenuItem),
  customer_name: String,
  notes: String,
  checkout: CheckoutInfo,
) -> String {
  "https://wa.me/"
  <> whatsapp_number
  <> "?text="
  <> encode_uri_component(build_message(
    cart,
    menu,
    customer_name,
    notes,
    checkout,
  ))
}

pub fn build_message(
  cart: List(CartItem),
  menu: List(MenuItem),
  customer_name: String,
  notes: String,
  checkout: CheckoutInfo,
) -> String {
  let items =
    cart
    |> list.index_map(fn(cart_item, index) {
      line_description(cart_item, index + 1, menu)
    })
    |> list.filter_map(fn(line) { line })
    |> string.join("\n")

  let name = case string.trim(customer_name) {
    "" -> "Não informado"
    name -> name
  }

  let notes_text = case string.trim(notes) {
    "" -> "Nenhuma"
    notes -> notes
  }

  let address_lines = case checkout.order_type {
    Entrega -> [
      "*Endereço de entrega:* " <> string.trim(checkout.delivery_address),
    ]
    Retirada -> []
  }

  let cash_lines = case checkout.payment_method {
    Dinheiro -> ["*Troco para:* " <> string.trim(checkout.cash_note)]
    _ -> []
  }

  string.join(
    list.flatten([
      [
        "*DOKA'S LANCHES*",
        "",
        "*Novo pedido*",
        "",
        "*Itens:*",
        items,
        "",
        "*Total:* " <> format_price(total_price(cart, menu)),
        "",
        "*Tipo de pedido:* " <> order_type_label(checkout.order_type),
      ],
      address_lines,
      [
        "*Forma de pagamento:* "
        <> payment_method_label(checkout.payment_method),
      ],
      cash_lines,
      [
        "",
        "*Cliente:* " <> name,
        "*Observações:* " <> notes_text,
        "",
        "Pedido gerado pelo cardápio digital.",
      ],
    ]),
    "\n",
  )
}

fn line_description(
  cart_item: CartItem,
  position: Int,
  menu: List(MenuItem),
) -> Result(String, Nil) {
  case item_and_variation(menu, cart_item.item_id, cart_item.variation_index) {
    Ok(#(item, variation)) -> {
      let variation_text = case variation.label {
        "" -> ""
        label -> " (" <> label <> ")"
      }
      Ok(
        int.to_string(position)
        <> ". "
        <> item.name
        <> variation_text
        <> " x"
        <> int.to_string(cart_item.quantity)
        <> " - "
        <> format_price(variation.price * cart_item.quantity),
      )
    }
    Error(_) -> Error(Nil)
  }
}

// MENU ------------------------------------------------------------------------

pub fn menu() -> List(MenuItem) {
  list.append(lanches(), drinks())
}

fn single(
  id: Int,
  name: String,
  description: String,
  category: Category,
  price: Int,
) -> MenuItem {
  MenuItem(id, name, description, category, [Variation("", price)])
}

fn lanches() -> List(MenuItem) {
  [
    single(1, "01. Misto", "Presunto e Queijo", Lanches, 2300),
    single(2, "02. Bauru", "Presunto, Queijo e Tomate", Lanches, 2300),
    single(3, "03. Paulista", "Bife, Queijo, Tomate e Alface", Lanches, 4200),
    single(
      4,
      "04. Americano",
      "Bife, Presunto, Queijo, Ovo, Tomate e Alface",
      Lanches,
      4600,
    ),
    single(
      5,
      "05. Calabresa Egg",
      "Presunto, Queijo, Bacon, Calabresa, Ovo, Tomate e Alface",
      Lanches,
      3000,
    ),
    single(
      6,
      "06. Hot Dog Simples",
      "2 Salsichas, Milho, Batata palha, Tomate e Alface",
      Lanches,
      1800,
    ),
    single(
      7,
      "07. Hot Dog Especial",
      "2 Salsichas, Milho, Batata palha, Bacon, Calabresa, Tomate e Alface",
      Lanches,
      2200,
    ),
    single(
      8,
      "08. X-Palmito",
      "Presunto, Queijo, Palmito, Tomate e Alface",
      Lanches,
      2800,
    ),
    single(9, "09. X-Burguer", "2 Hambúrgueres, Queijo e Tomate", Lanches, 2200),
    single(
      10,
      "10. X-Salada",
      "2 Hambúrgueres, Queijo, Tomate e Alface",
      Lanches,
      2200,
    ),
    single(
      11,
      "11. X-Egg",
      "2 Hambúrgueres, Queijo, Ovo, Tomate e Alface",
      Lanches,
      2500,
    ),
    single(
      12,
      "12. X-Bacon",
      "2 Hambúrgueres, Queijo, Bacon, Tomate e Alface",
      Lanches,
      2800,
    ),
    single(
      13,
      "13. X-Bacon com Calabresa",
      "2 Hambúrgueres, Queijo, Bacon, Calabresa, Tomate e Alface",
      Lanches,
      2900,
    ),
    single(
      14,
      "14. X-Salame",
      "2 Hambúrgueres, Queijo, Salame, Tomate e Alface",
      Lanches,
      3000,
    ),
    single(
      15,
      "15. X-Calabresa",
      "2 Hambúrgueres, Queijo, Calabresa, Tomate e Alface",
      Lanches,
      2800,
    ),
    single(
      16,
      "16. X-Tudo Promoção",
      "1 Hambúrguer, Presunto, Queijo, Bacon, Calabresa, Ovo, Tomate e Alface",
      Lanches,
      3200,
    ),
    single(
      17,
      "17. X-Tudo Especial",
      "2 Hambúrgueres, Presunto, Queijo, Bacon, Calabresa, Ovo, Tomate e Alface",
      Lanches,
      3400,
    ),
    single(
      18,
      "18. X-Tudo com Bife",
      "Bife, Presunto, Queijo, Bacon, Calabresa, Ovo, Tomate e Alface",
      Lanches,
      4800,
    ),
    single(
      19,
      "19. X-Tudo Aberto",
      "2 Hambúrgueres, Presunto, Queijo, Bacon, Calabresa, 2 Ovos, Tomate e Alface",
      Lanches,
      3600,
    ),
    single(
      20,
      "20. Americano Aberto",
      "3 Bifes, Presunto, Queijo, Bacon, Calabresa, 2 Ovos, Tomate e Alface",
      Lanches,
      4800,
    ),
    single(
      21,
      "21. Frango Desfiado",
      "Frango desfiado, Queijo, Catupiry, Milho, Tomate e Alface",
      Lanches,
      3400,
    ),
    single(
      22,
      "22. Hambúrguer Simples",
      "1 Hambúrguer, Queijo, Milho, Tomate e Alface",
      Lanches,
      2000,
    ),
  ]
}

fn drinks() -> List(MenuItem) {
  [
    MenuItem(23, "Coca-Cola", "", Refrigerantes, [
      Variation("Lata", 700),
      Variation("600ml", 900),
      Variation("1 Litro", 1200),
      Variation("2 Litros", 1700),
    ]),
    MenuItem(24, "Fanta", "", Refrigerantes, [
      Variation("Lata", 700),
      Variation("600ml", 900),
      Variation("2 Litros", 1400),
    ]),
    MenuItem(25, "Sprite", "", Refrigerantes, [
      Variation("Lata", 700),
      Variation("600ml", 900),
      Variation("2 Litros", 1400),
    ]),
    MenuItem(26, "Guaraná Antartica", "", Refrigerantes, [
      Variation("Lata", 700),
      Variation("1 Litro", 1200),
      Variation("2 Litros", 1400),
    ]),
    MenuItem(27, "Vencetex", "", Refrigerantes, [
      Variation("600ml", 600),
      Variation("1 Litro", 700),
      Variation("2 Litros", 1000),
    ]),
    single(28, "Skol", "", BebidasLata, 600),
    single(29, "Brahma", "", BebidasLata, 600),
    single(30, "Antartica", "", BebidasLata, 600),
    MenuItem(31, "Abacaxi", "", Sucos, [
      Variation("500ml", 800),
      Variation("1 Litro", 1500),
    ]),
    MenuItem(32, "Abacaxi c/ Hortelã", "", Sucos, [
      Variation("500ml", 800),
      Variation("1 Litro", 1500),
    ]),
    MenuItem(33, "Acerola", "", Sucos, [
      Variation("500ml", 800),
      Variation("1 Litro", 1500),
    ]),
    MenuItem(34, "Maracujá", "", Sucos, [
      Variation("500ml", 800),
      Variation("1 Litro", 1500),
    ]),
    MenuItem(35, "Laranja", "", Sucos, [
      Variation("500ml", 800),
      Variation("1 Litro", 1500),
    ]),
  ]
}
