(**
 * Copyright (c) 2013-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open OUnit2
open Layout_test_utils
open Layout_generator_test_utils

module S = Ast_builder.Statements
module E = Ast_builder.Expressions
module L = Layout_builder

let expected_object2_layout prop1 prop2 =
  let prop1_layout = Js_layout_generator.object_property prop1 in
  let prop2_layout = Js_layout_generator.object_property prop2 in
  L.(loc (sequence ~break:Layout.Break_if_needed ~inline:(true, true) ~indent:0 [
    fused [
      atom "{";
      flat_pretty_space;
      sequence ~break:Layout.Break_if_needed [
        fused [
          prop1_layout;
          Layout.IfBreak ((atom ","), (fused [atom ","; pretty_space]));
        ];
        fused [
          prop2_layout;
          Layout.IfBreak ((Layout.IfPretty ((atom ","), empty)), empty);
        ];
      ];
      flat_pretty_space;
      atom "}";
    ];
  ]))

let tests = [
  "empty_object" >:: begin fun ctxt ->
    let ast = E.object_ [] in
    let layout = Js_layout_generator.expression ast in
    assert_layout ~ctxt L.(loc (atom "{}")) layout;
    assert_output ~ctxt "{}" layout;
    assert_output ~ctxt ~pretty:true "{}" layout;
  end;

  (* `{ foo: x, bar: y }` rather than `{foo: x, bar: y}` *)
  "flat_spaces_inside_braces" >:: begin fun ctxt ->
    let prop1 = E.object_property (E.object_property_key "foo") (E.identifier "x") in
    let prop2 = E.object_property (E.object_property_key "bar") (E.identifier "y") in
    let ast = E.object_ [prop1; prop2] in
    let layout = Js_layout_generator.expression ast in
    assert_layout ~ctxt (expected_object2_layout prop1 prop2) layout;
    assert_output ~ctxt "{foo:x,bar:y}" layout;
    assert_output ~ctxt ~pretty:true "{ foo: x, bar: y }" layout;
  end;

  (* if it wraps, there's a trailing comma *)
  "newlines_and_trailing_comma" >:: begin fun ctxt ->
    let x40 = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" in
    let prop1 = E.object_property (E.object_property_key "foo") (E.identifier x40) in
    let prop2 = E.object_property (E.object_property_key "bar") (E.identifier x40) in
    let ast = E.object_ [prop1; prop2] in
    let layout = Js_layout_generator.expression ast in
    assert_layout ~ctxt (expected_object2_layout prop1 prop2) layout;
    assert_output ~ctxt ("{foo:"^x40^",bar:"^x40^"}") layout;
    assert_output ~ctxt ~pretty:true ("{\n  foo: "^x40^",\n  bar: "^x40^",\n}") layout;
  end;

  (* a function value forces the whole object to break in pretty mode *)
  "object_property_is_function" >:: begin fun ctxt ->
    let prop1 = E.object_property (E.object_property_key "foo") (E.identifier "x") in
    let prop2 = E.object_property (E.object_property_key "bar") (E.function_ ()) in
    let prop3 = E.object_property (E.object_property_key "baz") (E.identifier "y") in
    let ast = E.object_ [prop1; prop2; prop3] in
    let layout = Js_layout_generator.expression ast in
    let prop1_layout = Js_layout_generator.object_property prop1 in
    let prop2_layout = Js_layout_generator.object_property prop2 in
    let prop3_layout = Js_layout_generator.object_property prop3 in
    assert_layout ~ctxt
      L.(loc (sequence ~break:Layout.Break_if_needed ~inline:(true, true) ~indent:0 [
        fused [
          atom "{";
          flat_pretty_space;
          sequence ~break:Layout.Break_if_needed [
            fused [
              prop1_layout;
              Layout.IfBreak ((atom ","), (fused [
                atom ",";
                pretty_space;
              ]));
            ];
            fused [
              pretty_newline;
              prop2_layout;
              Layout.IfBreak ((atom ","), (fused [
                atom ",";
                pretty_space;
              ]));
            ];
            fused [
              pretty_newline;
              prop3_layout;
              Layout.IfBreak ((Layout.IfPretty ((atom ","), empty)), empty);
            ];
          ];
          flat_pretty_space;
          atom "}";
        ];
      ]))
      layout;
    assert_output ~ctxt "{foo:x,bar:function(){},baz:y}" layout;
    assert_output ~ctxt ~pretty:true "{\n  foo: x,\n  \n  bar: function() {},\n  \n  baz: y,\n}" layout;
  end;

  "object_property_is_method" >:: begin fun ctxt ->
    let layout = Js_layout_generator.expression (
      E.object_ [
        E.object_method (E.object_property_key "foo");
      ]
    ) in
    assert_output ~ctxt "{foo(){}}" layout;
    assert_output ~ctxt ~pretty:true "{ foo() {} }" layout;
  end;

  "object_property_is_generator_method" >:: begin fun ctxt ->
    let layout = Js_layout_generator.expression (
      E.object_ [
        E.object_method ~generator:true (E.object_property_key "foo");
      ]
    ) in
    assert_output ~ctxt "{*foo(){}}" layout;
    assert_output ~ctxt ~pretty:true "{ *foo() {} }" layout;
  end;

  "object_property_is_sequence" >:: begin fun ctxt ->
    let layout = Js_layout_generator.expression (
      E.object_ [
        E.object_property
          (E.object_property_key "foo")
          (E.sequence [E.identifier "x"; E.identifier "y"]);
      ]
    ) in
    assert_output ~ctxt "{foo:(x,y)}" layout;
    assert_output ~ctxt ~pretty:true "{ foo: (x, y) }" layout;
  end;

  "object_property_key_is_literal" >:: begin fun ctxt ->
    let layout = Js_layout_generator.expression (
      E.object_ [
        E.object_property_with_literal
          (Ast_builder.Literals.string "foo")
          (E.literal (Ast_builder.Literals.string "bar"));
      ]
    ) in
    assert_output ~ctxt ~msg:"string literal keys should be quoted"
      "{\"foo\":\"bar\"}" layout;
    assert_output ~ctxt ~msg:"string literal keys should be quoted" ~pretty:true
      "{ \"foo\": \"bar\" }" layout;
  end;

  "object_property_key_is_computed" >:: begin fun ctxt ->
    let b80 = String.make 80 'b' in
    let ast = Ast_builder.expression_of_string ("{["^b80^"]: 123}") in
    let layout = Js_layout_generator.expression ast in
    assert_output ~ctxt
      ("{["^b80^"]:123}")
      layout;
    assert_output ~ctxt ~pretty:true
      ("{\n  [\n    "^b80^"\n  ]: 123,\n}")
      layout;

    let b40 = String.make 40 'b' in
    let ast = Ast_builder.expression_of_string ("{["^b40^"+"^b40^"]: 123}") in
    let layout = Js_layout_generator.expression ast in
    assert_output ~ctxt
      ("{["^b40^"+"^b40^"]:123}")
      layout;
    (* TODO: the second b40 should wrap *)
    assert_output ~ctxt ~pretty:true
      ("{\n  [\n    "^b40^" + "^b40^"\n  ]: 123,\n}")
      layout;
  end;
]
