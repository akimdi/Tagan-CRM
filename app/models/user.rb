class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :token_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :lockable, :timeoutable

  before_save :ensure_authentication_token
  acts_as_api

  api_accessible :basic do |t|
    t.add :id
    t.add :email
    # t.add :username
    t.add :created_at
  end

  api_accessible :default_token, extend: :basic do |t|
    t.add :authentication_token, as: :access_token
  end

  api_accessible :my_profile_mode, extend: :default_token do |t|
    t.add :sign_in_count
    t.add :current_sign_in_at
    t.add :current_sign_in_ip
    t.add :confirmed_at
    t.add lambda{ |usr| usr.profile.as_api_response(:basic) rescue nil }, as: :profile
  end

  def validate_request!(request, params)
    if access_locked?
      errors.add(:account,'is locked please contact us')
    # elsif !confirmed?
    #   errors.add(:email,'is not confirmed yet')
    elsif timedout?(current_sign_in_at)
      errors.add(:session, 'expired. Please make re-login.')
    else
      sign_in_attributes = {
          current_sign_in_ip: request.env['REMOTE_ADDR'],
          current_sign_in_at: DateTime.now,
          last_sign_in_at: DateTime.now,
          last_sign_in_ip: request.env['REMOTE_ADDR'],
          sign_in_count:   (sign_in_count.to_i + 1)
      }

      update_columns(sign_in_attributes)
    end
  end



  def ensure_authentication_token
    self.authentication_token ||= generate_authentication_token
  end

  private

  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end
end