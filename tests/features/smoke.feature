Feature: The feature runner runs

  Scenario: Fields are counted
    Given nothing has been read
    When 3 fields are read
    And 4 fields are read
    Then 7 fields have been read
