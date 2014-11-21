require "aba/version"
require "aba/validations"
require "aba/transaction"

class Aba
  include Aba::Validations

  attr_accessor :bsb, :account_number, :financial_institution, :user_name, :user_id,
                :description, :process_at, :name_of_remitter

  attr_reader :errors

  validates_presence_of :financial_institution, :user_name, :user_id, :description, :process_at
  validates_bsb :bsb

  def initialize
    @transactions = []
    @errors = []

    yield self if block_given?
  end

  # Create a transaction record
  def transaction
    transaction = Transaction.new(trace_bsb: self.bsb, trace_account_number: self.account_number, name_of_remitter: self.name_of_remitter)
    yield transaction
    @transactions << transaction
  end

  def valid?
    super.valid? && @transactions.inject(true) { |res, t| res &&= t.valid? }
  end

  def to_s
    # Descriptive record
    output = "#{descriptive_record}\r\n"
    
    # Transactions records
    output += @transactions.map{ |t| t.to_s }.join("\r\n")

    # Batch control record
    output += "\r\n#{batch_control_record}"
  end

  private

  def descriptive_record
    # Record type
    output = "0"

    # Bank/State/Branch number of the funds account with a hyphen in the 4th character position. e.g. 013-999. 
    output += self.bsb.ljust(7, " ")

    # Funds account number.
    output += self.account_number.ljust(9, " ")

    # Reserved
    output += " "

    # Sequence number 
    output += "01"

    # Must contain the bank mnemonic that is associated with the BSB of the funds account. e.g. ‘ANZ’. 
    output += self.financial_institution

    # Reserved 
    output += " " * 7

    # Name of User supplying File as advised by User's Financial Institution
    output += self.user_name.ljust(26, " ")

    # Direct Entry User ID. 
    output += self.user_id.rjust(6, "0")

    # Description of payments in the file (e.g. Payroll, Creditors etc.). 
    output += self.description.ljust(12, " ")

    # Date and time on which the payment is to be processed.
    output += self.process_at.strftime("%d%m%y%H%M")

    # Reserved
    output += " " * 36
  end

  def batch_control_record
    # Record type
    output = "7"

    # BSB Format Filler
    output += "999-999"

    # Reserved
    output += " " * 12

    net_total_amount    = 0
    credit_total_amount = 0
    debit_total_amount  = 0

    @transactions.each do |t|
      net_total_amount += t.amount
      credit_total_amount += t.amount if t.amount > 0
      debit_total_amount += t.amount if t.amount < 0
    end

    # Must equal the difference between File Credit & File Debit Total Amounts. Show in cents without punctuation
    output += net_total_amount.abs.to_s.rjust(10, "0")

    # Batch Credit Total Amount 
    output += credit_total_amount.abs.to_s.rjust(10, "0")

    # Batch Debit Total Amount 
    output += debit_total_amount.abs.to_s.rjust(10, "0")

    # Reserved
    output += " " * 24

    # Batch Total Item Count 
    output += @transactions.size.to_s.rjust(6, "0")

    # Reserved
    output += " " * 40
  end
end