import dokas/app
import dokas/domain
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import lustre/element

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn format_price_test() {
  assert domain.format_price(2300) == "R$ 23,00"
  assert domain.format_price(700) == "R$ 7,00"
  assert domain.format_price(0) == "R$ 0,00"
  assert domain.format_price(1234) == "R$ 12,34"
}

pub fn menu_has_all_categories_test() {
  let menu = domain.menu()
  assert list.length(menu) == 35
  assert list.length(domain.items_for_category(menu, domain.Lanches)) == 22
  assert list.length(domain.items_for_category(menu, domain.Refrigerantes)) == 5
  assert list.length(domain.items_for_category(menu, domain.BebidasLata)) == 3
  assert list.length(domain.items_for_category(menu, domain.Sucos)) == 5
}

pub fn cart_total_test() {
  let menu = domain.menu()
  let cart = [domain.CartItem(1, 0, 2), domain.CartItem(23, 0, 1)]
  assert domain.total_quantity(cart) == 3
  assert domain.total_price(cart, menu) == 5300
  assert domain.format_price(domain.total_price(cart, menu)) == "R$ 53,00"
}

pub fn per_item_limit_test() {
  let cart = [domain.CartItem(1, 0, 20)]
  assert domain.increment(cart, 1, 0) == Error(domain.ItemLimitReached)
  assert domain.increment([], 1, 0) == Ok([domain.CartItem(1, 0, 1)])
}

pub fn total_limit_test() {
  let cart = [
    domain.CartItem(1, 0, 20),
    domain.CartItem(2, 0, 20),
    domain.CartItem(3, 0, 10),
  ]
  assert domain.total_quantity(cart) == 50
  assert domain.increment(cart, 4, 0) == Error(domain.CartLimitReached)
}

pub fn decrement_and_remove_test() {
  assert domain.decrement([domain.CartItem(1, 0, 2)], 1, 0)
    == [domain.CartItem(1, 0, 1)]
  assert domain.decrement([domain.CartItem(1, 0, 1)], 1, 0) == []
  assert domain.remove(
      [domain.CartItem(1, 0, 3), domain.CartItem(2, 0, 1)],
      1,
      0,
    )
    == [domain.CartItem(2, 0, 1)]
}

pub fn clean_name_test() {
  assert domain.clean_name("Maria\u{0000} Silva") == "Maria Silva"
  assert domain.clean_name("a\nb") == "ab"
  assert domain.clean_name("  Maria  ") == "  Maria  "
  assert string.length(domain.clean_name(string.repeat("a", 100))) == 80
}

pub fn clean_notes_test() {
  assert domain.clean_notes("sem cebola\nsem tomate")
    == "sem cebola\nsem tomate"
  assert domain.clean_notes("a\u{0000}b") == "ab"
  assert string.length(domain.clean_notes(string.repeat("a", 900))) == 500
}

pub fn encoding_test() {
  assert domain.encode_uri_component("a b\nç") == "a%20b%0A%C3%A7"
  // Emojis are astral-plane characters: the encoder must yield valid UTF-8.
  assert domain.encode_uri_component("🍔") == "%F0%9F%8D%94"

  let checkout = domain.CheckoutInfo(domain.Retirada, "", domain.Pix, "")
  let url =
    domain.whatsapp_url(
      [domain.CartItem(1, 0, 1)],
      domain.menu(),
      "João",
      "sem cebola",
      checkout,
    )
  assert string.starts_with(
    url,
    "https://wa.me/" <> domain.whatsapp_number <> "?text=",
  )
  assert string.contains(url, "%0A")
  assert string.contains(url, "%C3%A7")
  assert string.contains(url, "%C3%A3")
  assert string.contains(url, "%EF%BF%BD") == False
}

pub fn storage_roundtrip_test() {
  let cart = [domain.CartItem(1, 0, 2), domain.CartItem(23, 1, 3)]
  let stored = domain.cart_to_storage(cart)
  assert stored == "1:0:2;23:1:3"
  assert domain.cart_from_storage(stored, domain.menu()) == cart
}

pub fn corrupt_storage_test() {
  let menu = domain.menu()
  assert domain.cart_from_storage("", menu) == []
  assert domain.cart_from_storage("garbage", menu) == []
  assert domain.cart_from_storage("1:0:999", menu) == []
  assert domain.cart_from_storage("999:0:1", menu) == []
  assert domain.cart_from_storage("1:99:1", menu) == []
}

pub fn storage_caps_total_test() {
  let cart = domain.cart_from_storage("1:0:20;2:0:20;3:0:20", domain.menu())
  assert domain.total_quantity(cart) == 50
}

pub fn view_renders_empty_cart_test() {
  let model =
    app.Model(
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

  let rendered = element.to_string(app.view(model))
  assert string.contains(rendered, "Doka")
  assert string.contains(rendered, "01. Misto")
  assert string.contains(rendered, "Adicione pelo menos um item ao pedido")
}

pub fn view_renders_whatsapp_link_test() {
  let model =
    app.Model(
      menu: domain.menu(),
      cart: [domain.CartItem(1, 0, 1)],
      customer_name: "Maria",
      notes: "sem cebola",
      order_type: Some(domain.Retirada),
      delivery_address: "",
      payment_method: Some(domain.Pix),
      cash_note: "",
      active_category: domain.Lanches,
      error: None,
    )

  let rendered = element.to_string(app.view(model))
  assert string.contains(
    rendered,
    "https://wa.me/" <> domain.whatsapp_number <> "?text=",
  )
  assert string.contains(rendered, "Maria")
}

pub fn view_renders_limit_error_test() {
  let model =
    app.Model(
      menu: domain.menu(),
      cart: [domain.CartItem(1, 0, 20)],
      customer_name: "",
      notes: "",
      order_type: None,
      delivery_address: "",
      payment_method: None,
      cash_note: "",
      active_category: domain.Lanches,
      error: Some(domain.ItemLimitReached),
    )

  let rendered = element.to_string(app.view(model))
  assert string.contains(rendered, "Limite de 20 unidades por item atingido")
}

pub fn order_and_payment_labels_test() {
  assert domain.order_type_label(domain.Retirada)
    == "Retirada no estabelecimento"
  assert domain.order_type_label(domain.Entrega) == "Entrega"
  assert domain.payment_method_label(domain.Pix) == "Pix"
  assert domain.payment_method_label(domain.CartaoDebito) == "Cartão de débito"
  assert domain.payment_method_label(domain.CartaoCredito)
    == "Cartão de crédito"
  assert domain.payment_method_label(domain.Dinheiro) == "Dinheiro"
}

pub fn checkout_validation_test() {
  assert domain.missing_checkout_fields(None, "", None, "")
    == [domain.OrderTypeMissing, domain.PaymentMissing]
  assert domain.is_checkout_complete(
    Some(domain.Retirada),
    "",
    Some(domain.Pix),
    "",
  )
  assert domain.missing_checkout_fields(
      Some(domain.Entrega),
      "   ",
      Some(domain.Pix),
      "",
    )
    == [domain.AddressMissing]
  assert domain.is_checkout_complete(
    Some(domain.Entrega),
    "Rua A, 10",
    Some(domain.Pix),
    "",
  )
  assert domain.missing_checkout_fields(
      Some(domain.Retirada),
      "",
      Some(domain.Dinheiro),
      "  ",
    )
    == [domain.CashNoteMissing]
  assert domain.is_checkout_complete(
    Some(domain.Retirada),
    "",
    Some(domain.Dinheiro),
    "R$ 50",
  )
}

pub fn build_message_order_details_test() {
  let delivery =
    domain.build_message(
      [domain.CartItem(1, 0, 1)],
      domain.menu(),
      "Maria",
      "",
      domain.CheckoutInfo(
        domain.Entrega,
        "Rua das Flores, 123",
        domain.Dinheiro,
        "R$ 100",
      ),
    )
  assert string.starts_with(delivery, "*DOKA'S LANCHES*")
  assert string.contains(delivery, "*Tipo de pedido:* Entrega")
  assert string.contains(delivery, "*Endereço de entrega:* Rua das Flores, 123")
  assert string.contains(delivery, "*Forma de pagamento:* Dinheiro")
  assert string.contains(delivery, "*Troco para:* R$ 100")
  assert string.contains(delivery, "\u{FFFD}") == False

  let pickup =
    domain.build_message(
      [domain.CartItem(1, 0, 1)],
      domain.menu(),
      "Maria",
      "",
      domain.CheckoutInfo(domain.Retirada, "", domain.Pix, ""),
    )
  assert string.contains(
    pickup,
    "*Tipo de pedido:* Retirada no estabelecimento",
  )
  assert string.contains(pickup, "*Forma de pagamento:* Pix")
  assert string.contains(pickup, "*Endereço de entrega:*") == False
  assert string.contains(pickup, "*Troco para:*") == False
}

pub fn clean_address_and_cash_note_test() {
  assert domain.clean_address("Rua A\u{0000}, 10") == "Rua A, 10"
  assert string.length(domain.clean_address(string.repeat("a", 200))) == 160
  assert domain.clean_cash_note("R$ 50\u{0000}") == "R$ 50"
  assert string.length(domain.clean_cash_note(string.repeat("1", 50))) == 30
}

pub fn view_renders_delivery_fields_test() {
  let model =
    app.Model(
      menu: domain.menu(),
      cart: [domain.CartItem(1, 0, 1)],
      customer_name: "Maria",
      notes: "",
      order_type: Some(domain.Entrega),
      delivery_address: "",
      payment_method: Some(domain.Dinheiro),
      cash_note: "",
      active_category: domain.Lanches,
      error: None,
    )

  let rendered = element.to_string(app.view(model))
  assert string.contains(rendered, "Endereço de entrega")
  assert string.contains(rendered, "Nota para troco")
}
