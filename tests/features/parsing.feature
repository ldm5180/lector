Feature: A parsed document reads its fields, or fails without raising

  A whole document is parsed once, and its top-level fields are then
  read by name.  Malformed input is a verdict, never an exception, and
  leaves nothing to read.  The parse stops at the first complete value,
  so it does not catch a file with something after its object: the
  single-object check does (shape.feature).

  Scenario: A well-formed object parses and its fields read by name
    Given a document:
      """
      {"status": "FILLED", "quantity": "2"}
      """
    When the document is parsed
    Then the parse succeeds
    And the field status is present
    And the field missing is absent
    When the field status is read
    Then the value is "FILLED"
    When the field quantity is read
    Then the value is "2"

  Scenario: A nested payload's top-level field is not shadowed
    Given a document:
      """
      {"status": "WORKING", "children": [{"status": "PENDING"}]}
      """
    When the document is parsed
    Then the parse succeeds
    When the field status is read
    Then the value is "WORKING"

  Scenario: Malformed input fails, and leaves nothing to read
    Given a document:
      """
      {"broken":
      """
    When the document is parsed
    Then the parse fails
    And the field broken is absent
    When the field broken is read
    Then the value is absent

  Scenario: Something after the object does not stop the parse
    Given a document:
      """
      {"a": "1"}trailing
      """
    When the document is parsed
    Then the parse succeeds
    When the field a is read
    Then the value is "1"

  Scenario: A dotted key does not reach a field inside a nested object
    Given a document:
      """
      {"status": "WORKING", "child": {"status": "PENDING"}}
      """
    When the document is parsed
    Then the parse succeeds
    When the field child.status is read
    Then the value is absent
