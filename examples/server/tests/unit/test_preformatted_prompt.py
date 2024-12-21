import pytest
from utils import *

server = ServerPreset.llama2()


@pytest.fixture(scope="module", autouse=True)
def create_server():
    global server
    server = ServerPreset.llama2()


@pytest.mark.parametrize(
    "model,data,max_tokens,re_content,n_prompt,n_predicted,finish_reason, prompt",
    [
        (
            "llama2",
            {
                "messages": [
                    {"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": "What day comes after Monday?"},
                ]
            },
            16,
            "(Tuesday)+",
            56,
            8,
            "stop",
            """<s> <|im_start|>system
You are a helpful assistant.<|im_end|>
<|im_start|>user
What day comes after Monday?<|im_end|>
<|im_start|>assistant
""",
        ),
        (
            "llama2",
            {
                "prompt": """<s>[INST] <<SYS>>
You are a helpful assistant.
<</SYS>>

What day comes after Monday? [/INST]""",
                "add_special": False,
            },
            1024,
            "(Tuesday)+",
            33,
            25,
            "stop",
            """<s> [INST] <<SYS>>
You are a helpful assistant.
<</SYS>>

What day comes after Monday? [/INST]""",
        ),
    ],
)
def test_chat_completion_without_preformatted_prompt(
    model, data, max_tokens, re_content, n_prompt, n_predicted, finish_reason, prompt
):
    global server
    server.start()
    res = server.make_request(
        "POST",
        "/chat/completions",
        data={
            "model": model,
            "max_tokens": max_tokens,
            **data,
        },
    )
    assert res.status_code == 200
    assert (
        "cmpl" in res.body["id"]
    )  # make sure the completion id has the expected format
    assert res.body["model"] == model
    # assert res.body["usage"]["prompt_tokens"] == n_prompt
    # assert res.body["usage"]["completion_tokens"] == n_predicted
    choice = res.body["choices"][0]
    assert "assistant" == choice["message"]["role"]
    assert match_regex(re_content, choice["message"]["content"])
    assert choice["finish_reason"] == finish_reason
    assert res.body["__verbose"]["prompt"] == prompt
