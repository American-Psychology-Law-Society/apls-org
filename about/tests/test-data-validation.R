helper_path <- if (file.exists("about/_data-validation.R")) {
  "about/_data-validation.R"
} else {
  "../_data-validation.R"
}
source(helper_path)

expect_error <- function(code, pattern) {
  error <- tryCatch(
    {
      force(code)
      NULL
    },
    error = identity
  )
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}

valid_ec <- data.frame(
  Name = c("Alex Example", "Bailey Example"),
  Position = c("President", "Secretary"),
  Email = c("alex@example.org", "bailey@example.org")
)
valid_conf <- data.frame(
  Name = "Casey Example",
  Term = "2027",
  Position = "Co-chair"
)
stopifnot(isTRUE(validate_leadership_inputs(valid_ec, valid_conf)))
expect_error(
  validate_leadership_inputs(valid_ec[c("Name", "Position")], valid_conf),
  "missing required column"
)
expect_error(validate_leadership_inputs(valid_ec[0, ], valid_conf), "no data rows")
bad_email <- valid_ec
bad_email$Email[1] <- "not-an-email"
expect_error(validate_leadership_inputs(bad_email, valid_conf), "invalid email")
duplicate_ec <- rbind(valid_ec, valid_ec[1, ])
expect_error(validate_leadership_inputs(duplicate_ec, valid_conf), "duplicate values")

valid_descriptions <- data.frame(
  key = c("CommitteeA", "CommitteeB"),
  name = c("Committee A", "Committee B"),
  description = c("A", "B"),
  responsibilities = "",
  values = "",
  meetings = "",
  membership = "",
  reporting = "",
  other = "",
  chair = "",
  email = "",
  stringsAsFactors = FALSE
)
valid_members <- data.frame(
  key = c("CommitteeA", "CommitteeB"),
  Position = c("Chair", "Member"),
  Name = c("Alex Example", "Bailey Example"),
  Email = c("alex@example.org", ""),
  Term = c("2026-2029", "2026-2029"),
  Additional = "",
  stringsAsFactors = FALSE
)
stopifnot(isTRUE(validate_committee_inputs(
  valid_descriptions,
  valid_members,
  c("CommitteeA", "CommitteeB")
)))
expect_error(
  validate_committee_inputs(valid_descriptions, valid_members, "CommitteeA"),
  "missing tabs"
)
bad_members <- valid_members
bad_members$key[1] <- "Unknown"
expect_error(
  validate_committee_inputs(valid_descriptions, bad_members),
  "unknown committee key"
)
bad_members <- valid_members
bad_members$Email[1] <- "invalid"
expect_error(validate_committee_inputs(valid_descriptions, bad_members), "invalid email")
expect_error(
  validate_committee_inputs(valid_descriptions, rbind(valid_members, valid_members[1, ])),
  "duplicate values"
)

transaction_dir <- tempfile("apls-data-transaction-")
dir.create(transaction_dir)
targets <- file.path(transaction_dir, c("first.txt", "second.txt"))
writeLines("old first", targets[1])
writeLines("old second", targets[2])
staged <- file.path(transaction_dir, c("new-first.tmp", "new-second.tmp"))
writeLines("new first", staged[1])
writeLines("new second", staged[2])
atomic_replace_files(staged, targets)
stopifnot(
  identical(readLines(targets[1]), "new first"),
  identical(readLines(targets[2]), "new second")
)
unlink(transaction_dir, recursive = TRUE)

message("All data validation tests passed.")
