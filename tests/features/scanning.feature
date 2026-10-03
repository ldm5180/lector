Feature: A field is read out of a nested payload without parsing it

  A field is read straight out of a payload's text: the value after
  a key, the digits after one, or a field of the object whose other
  field matches.  No parse is needed -- a document the parser would
  refuse still gives up its field -- and nothing raises.

  Scenario: The string value after a key, spaced or tight
    Given a document:
      """
      {"name": "ada", "kind":"crate"}
      """
    When the string value of name is read
    Then the value is "ada"
    When the string value of kind is read
    Then the value is "crate"

  Scenario: A number past what an integer holds comes back verbatim
    Given a document:
      """
      {"orderId": 100047, "big": 99999999999999999999}
      """
    When the number value of orderId is read
    Then the value is "100047"
    When the number value of big is read
    Then the value is "99999999999999999999"

  Scenario: The field of the object whose key matches
    Given the document named account-roster
    When the hashValue of the object whose accountNumber is 222 is read
    Then the value is "BBB"
    When the hashValue of the object whose accountNumber is 111 is read
    Then the value is "AAA"

  Scenario: A later occurrence is read by starting after the first
    Given a document:
      """
      {"id": "first"} {"id": "second"}
      """
    When the string value of id after the first id is read
    Then the value is "second"

  Scenario: A field inside a nested array is read directly
    Given the document named order-status
    When the quantity of the object whose symbol is QQQ is read
    Then the value is "7"

  Scenario: An escaped quote is not unescaped: the value ends at it
    Given a document:
      """
      {"k": "a\"b"}
      """
    When the string value of k is read
    Then the value is "a\"
