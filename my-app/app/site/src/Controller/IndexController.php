<?php

declare(strict_types= 1);

namespace App\Site\Controller;

use Marko\Routing\Attributes\Get;
use Marko\Routing\Http\Response;

class IndexController{

    #[Get("/")]
    public function index(): Response
    {
        return new Response(
            body: "Hello, this is Marko Framework!",
        );

    }
}