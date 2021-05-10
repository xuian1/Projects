using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class KeyInput : MonoBehaviour
{
	private int moveSpeed = 5;
	private float rotationValue = 0;
	
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if(Input.GetKey("a")){
			move(-1, 0);
		}
		if(Input.GetKey("w")){
			move(0, 1);
		}
		if(Input.GetKey("d")){
			move(1, 0);
		}
		if(Input.GetKey("s")){
			move(0, -1);
		}
		float x = GameObject.Find("Main Camera").GetComponent<Camera>().ScreenToWorldPoint(Input.mousePosition).x-transform.position.x;
		float y = GameObject.Find("Main Camera").GetComponent<Camera>().ScreenToWorldPoint(Input.mousePosition).y-transform.position.y;
		if(Input.GetMouseButton(0)){
			createBullet(x, y);
		}
		if(Time.frameCount % 5 == 0){
			createObstacle(transform.position.x, transform.position.y);
		}
		if(x == 0){
			if(y == 0){
				rotationValue = -40;
			}
			else{
				rotationValue = 140;
			}
		}
		else{
			rotationValue = (float)((180/Math.PI)*Math.Atan(Math.Abs(x/y)));
			if(y < 0){
				rotationValue = (90f-rotationValue) + 90f;
			}
			if(x > 0){
				rotationValue = -rotationValue;
			}
			rotationValue= rotationValue-40f;
		}
		transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.Euler(0, 0, rotationValue), Time.deltaTime*10);
    }
	
	// Moves the ship 
	private void move(int x, int y){
		transform.position = transform.position + new Vector3(x*moveSpeed*Time.deltaTime, y*moveSpeed*Time.deltaTime, 0);
	}
	
	//Generates a bullet from the point of firing 
	private void createBullet(float x, float y){
		GameObject temp = new GameObject();
		temp.AddComponent<SpriteRenderer>().sprite = Resources.Load<Sprite>("Circle");
		temp.GetComponent<SpriteRenderer>().color = Color.green;
		temp.AddComponent<BulletLogic>().SetDir(x, y);
		temp.transform.position = this.transform.position;
	}
	
	//Generates an obstacle outside of screen
	private void createObstacle(float x, float y){
		int quadrant = UnityEngine.Random.Range(0, 8);
		float valx = UnityEngine.Random.Range(0f, 1f);
		float valy = UnityEngine.Random.Range(0f, 1f);
		float randx = UnityEngine.Random.Range(-5f, 5f);
		float randy = UnityEngine.Random.Range(-5f, 5f);
		if(quadrant == 0 | quadrant == 1 | quadrant == 2){
			valx += 1;
		}
		else if(quadrant == 4 | quadrant == 5 | quadrant == 6){
			valx -= 1;
		}
		if(quadrant == 6 | quadrant == 7 | quadrant == 0){
			valy += 1;
		}
		else if(quadrant == 2 | quadrant == 3 | quadrant == 4){
			valy -= 1;
		}
		GameObject temp = new GameObject();
		temp.AddComponent<SpriteRenderer>().sprite = Resources.Load<Sprite>("Circle");
		temp.GetComponent<SpriteRenderer>().color = Color.red;
		temp.transform.position = GameObject.Find("Main Camera").GetComponent<Camera>().ViewportToWorldPoint(new Vector3(valx, valy, 0.5f));
		temp.AddComponent<ObstacleLogic>().SetDir(x-temp.transform.position.x+randx, y-temp.transform.position.y+randy);
	}
}