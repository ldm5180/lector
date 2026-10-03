Feature: A missing key is empty, never an error

  Whatever way a key is missing -- not there, there without a colon,
  there with a value that never ends or with a value of the other
  shape -- reading it gives back an empty value.  Nothing raises, and
  a consumer tells "absent" from "present" by the value alone.

  Scenario: A key the document does not hold
    Given a document:
      """
      {"name": "ada", "orderId": 100047}
      """
    When the string value of missing is read
    Then the value is absent
    When the number value of missing is read
    Then the value is absent

  Scenario: A key with no colon after it
    Given a document:
      """
      {"k" "no-colon"}
      """
    When the string value of k is read
    Then the value is absent

  Scenario: A value that never ends
    Given a document:
      """
      {"k": "unterminated
      """
    When the string value of k is read
    Then the value is absent

  Scenario: A number where a string is asked for
    Given a document:
      """
      {"k": 42}
      """
    When the string value of k is read
    Then the value is absent

  Scenario: A string where a number is asked for
    Given a document:
      """
      {"k": "text"}
      """
    When the number value of k is read
    Then the value is absent

  Scenario: No object matches
    Given the document named account-roster
    When the hashValue of the object whose accountNumber is 333 is read
    Then the value is absent

  Scenario: An empty match value matches nothing
    Given the document named account-roster
    When the hashValue of the object whose accountNumber is "" is read
    Then the value is absent

  Scenario: A parsed document lacks the field
    Given a document:
      """
      {"name": "ada"}
      """
    When the document is parsed
    And the field missing is read
    Then the value is empty
