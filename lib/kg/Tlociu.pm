package kg::Tlociu;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { 'title' => 'kg::Tlociu' };
};

true;
