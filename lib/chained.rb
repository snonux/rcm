module RCM
  # To allow chained barwords, e.g. "i want a beer"
  module Chained
    def method_missing(method_name, *args) = ([method_name] + args.flatten).join(' ')
    def respond_to_missing? = true
  end
end
